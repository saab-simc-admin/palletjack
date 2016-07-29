class PalletJack
  class KeyTransformer
    class Reader < KeyTransformer
      def concatenate(value,param)
        value.split(param) if value
      end
    end

    class Writer < KeyTransformer
      def concatenate(value,param)
        value.join(param) if value
      end

      # Synthesize a pallet value by pasting others together.
      #
      # :call-seq:
      #   synthesize(nil, param)   -> string or nil
      #   synthesize(value, param) -> nil
      #
      # If +value+ is given, an earlier transform has already produced
      # a value for this key, so do nothing and return +nil+.
      #
      # Otherwise, use the parsed YAML structure in +param+ to build
      # and return a new value. If any failure occurs while building
      # the new value, return +nil+ to let another transform try.
      #
      # YAML structure:
      #
      #   - synthesize:
      #     - "rule"
      #     - "rule"
      #     ...
      #
      # Rules are strings used to build the new value. The value of
      # another key is inserted by <tt>#[key]</tt>, and all other
      # characters are copied verbatim.
      #
      # Rules are evaluated in order, and the first one to
      # successfully produce a value without failing a key lookup is
      # used.
      #
      # Example:
      #
      #   - chassis.nic.name:
      #     - synthesize:
      #       - "p#[chassis.nic.pcislot]p#[chassis.nic.port]"
      #       - "em#[chassis.nic.port]"

      def synthesize(value, param, result=String.new)
        return if value

        case param
        when String
          rex=/#\[([a-z0-9.-_]+)\]/i
          if md=rex.match(param) then
            result << md.pre_match
            return unless lookup = @pallet[md[1]]
            result << lookup.to_s
            synthesize(false, md.post_match, result)
          else
            result
          end
        else
          param.reduce(false) do |found_one, alternative|
            found_one || synthesize(false, alternative)
          end
        end
      end

      # Synthesize a pallet value from others, using regular
      # expressions to pull out parts of values.
      #
      # :call-seq:
      #   synthesize_regexp(nil, param)   -> string or nil
      #   synthesize_regexp(value, param) -> nil
      #
      # If +value+ is given, an earlier transform has already produced
      # a value for this key, so do nothing and return +nil+.
      #
      # Otherwise, use the parsed YAML structure in +param+ to build
      # and return a new value. If any failure occurs while building
      # the new value, return +nil+ to let another transform try.
      #
      # YAML structure:
      #
      #   - synthesize_regexp:
      #       sources:
      #         source0:
      #           key: "key"
      #           regexp: "regexp"
      #         source1:
      #           key: "key"
      #           regexp: "regexp"
      #         ...
      #       produce: "recipe"
      #
      # where:
      # [+sourceN+] Arbitrary number of sources for partial values,
      #             with arbitrary names
      # [+key+]     Name of the key to read a partial value from
      # [+regexp+]  Regular expression for parsing the value indicated
      #             by +key+, with named captures used to save
      #             substrings for producing the final value. Capture
      #             names must not be repeated within the same
      #             synthesize_regexp block.
      # [+produce+] A recipe for building the new value. Named
      #             captures are inserted by <tt>#[capture]</tt>, and
      #             all other characters are copied verbatim.
      #
      # Example:
      #
      # Take strings like +192.168.0.0_24+ from +pallet.ip_network+
      # and produce strings like +192.168.0.0/24+ in +net.ip.cidr+.
      #
      #  - net.ip.cidr:
      #    - synthesize_regexp:
      #        sources:
      #          ip_network:
      #            key: "pallet.ip_network"
      #            regexp: "^(?<network>[0-9.]+)_(?<prefix_length>[0-9]+)$"
      #        produce: "#[network]/#[prefix_length]"

      def synthesize_regexp(value, param, result=String.new)
        return if value

        captures = {}

        param["sources"].each do |_, source|
          # Trying to read values from a non-existent key. Return nil
          # and let another transform try.
          return unless lookup = @pallet[source["key"]]

          # Save all named captures
          Regexp.new(source["regexp"]).match(lookup) do |md|
            md.names.each do |name|
              captures[name] = md[name.to_sym]
            end
          end
        end

        # No captures succeeded. Return nil and let another transform
        # try.
        return if captures.length == 0

        # Making a copy of the string lets us use the destructive
        # gsub! function later, which tells us whether the
        # substitution succeeded
        product = param["produce"].dup

        captures.each do |name, match|
          # If a substitution fails, return nil and let another
          # transform try.
          return unless product.gsub!("#[#{name}]", match)
        end

        return product
      end
    end

    def initialize(key_transforms={})
      @key_transforms = key_transforms
    end

    # Destructively transform the values in +pallet+ according to the
    # loaded transform rules.
    #
    # YAML structure:
    #
    #   - key:
    #     - transform1:
    #         [transform-specific configuration]
    #     - transform2:
    #         [transform-specific configuration]
    #     [...]
    #
    # Transforms are evaluated in order from top to bottom, and the
    # first one to successfully produce a value is used.
    #
    # Transforms are methods in PalletJack::KeyTransformer::Writer,
    # called by name. They should return the new value, or +false+ if
    # unsuccessful.

    def transform!(pallet)
      @pallet = pallet
      @key_transforms.each do |keytrans_item|
        key, transforms = keytrans_item.flatten
        value = @pallet[key, shallow: true]

        transforms.each do |t|
          transform, param = t.flatten
          if self.respond_to?(transform.to_sym) then
            if new_value = self.send(transform.to_sym, value, param) then
              @pallet[key] = new_value
              break
            end
          end
        end
      end
      @hash
    end
  end
end
