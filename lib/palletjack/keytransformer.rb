require 'traceable'

class PalletJack
  class KeyTransformer
    class Reader < KeyTransformer
      def concatenate(param, context = {})
        context[:value].split(param) if context[:value]
      end
    end

    class Writer < KeyTransformer
      def concatenate(param, context = {})
        context[:value].join(param) if context[:value]
      end

      # Internal synthesize* helper method
      # N.B. rdoc will not be generated, because method is private.
      #
      # :call-seq:
      #   synthesize_internal(param, dictionary) -> string or nil
      #
      # Use the single +String+ or +Enumerable+ containing +String+
      # in +param+ to build and return a substitution value. If any
      # failure occurs while building the new value, return +nil+.
      #
      # Substitutions are made from key-value pairs in +dictionary+
      #
      # YAML structure:
      #
      #   - some_rule: "rule"
      #
      # or
      #
      #   - some_rule:
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

      def synthesize_internal(param, dictionary, result=String.new)
        case param
        when String
          rex=/#\[([[:alnum:]._-]+)\]/
          if md=rex.match(param) then
            result << md.pre_match
            return unless lookup = dictionary[md[1]]
            result << lookup.to_s
            synthesize_internal(md.post_match, dictionary, result)
          else
            result << param
          end
        else # Enumerable
          param.reduce(false) do |found_one, alternative|
            found_one || synthesize_internal(alternative, dictionary)
          end
        end
      end
      private :synthesize_internal

      # Synthesize a pallet value by pasting others together.
      #
      # :call-seq:
      #   synthesize(param, context)   -> string or nil
      #
      # If +context+ contains a non-nil +:value+, an earlier transform
      # has already produced a value for this key, so do nothing and
      # return +nil+.
      #
      # Otherwise, use the parsed YAML structure in +param+ to build
      # and return a new value. If any failure occurs while building
      # the new value, return +nil+ to let another transform try.
      #
      # YAML structure:
      #
      #   - synthesize: "rule"
      #
      # or
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
      #   - net.dns.fqdn:
      #     - synthesize: "#[net.ip.name].#[domain.name]"
      #
      #   - chassis.nic.name:
      #     - synthesize:
      #       - "p#[chassis.nic.pcislot]p#[chassis.nic.port]"
      #       - "em#[chassis.nic.port]"

      def synthesize(param, context = {})
        return if context[:value]
        
        synthesize_internal(param, context[:pallet])
      end

      # Synthesize a pallet value from others, using regular
      # expressions to pull out parts of values.
      #
      # :call-seq:
      #   synthesize_regexp(param, context)   -> string or nil
      #
      # If +context+ contains a non-nil +:value+, an earlier transform
      # has already produced a value for this key, so do nothing and
      # return +nil+.
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
      # Take strings like +192.168.0.0_24+ from +pallet.ipv4_network+
      # and produce strings like +192.168.0.0/24+ in +net.ipv4.cidr+.
      #
      #  - net.ipv4.cidr:
      #    - synthesize_regexp:
      #        sources:
      #          ipv4_network:
      #            key: "pallet.ipv4_network"
      #            regexp: "^(?<network>[0-9.]+)_(?<prefix_length>[0-9]+)$"
      #        produce: "#[network]/#[prefix_length]"

      def synthesize_regexp(param, context = {})
        return if context[:value]

        captures = {}

        param['sources'].each do |_, source|
          # Trying to read values from a non-existent key. Return nil
          # and let another transform try.
          return unless lookup = context[:pallet][source['key']]

          # Save all named captures
          Regexp.new(source['regexp']).match(lookup) do |md|
            md.names.each do |name|
              captures[name] = md[name.to_sym]
            end
          end
        end

        synthesize_internal(param['produce'], captures)
      end

      # Synthesized value will override an inherited value for a
      # +key+, but in some cases the intent is actually to only
      # synthesize a value when there is no inherited value. This
      # provides early termination of transforms for such keys.
      #
      # Example:
      #
      #  - net.layer2.name:
      #    - inherit: ~
      #    - synthesize: "#[chassis.nic.name]"

      def inherit(_, context = {})
        throw context[:abort] if context[:pallet][context[:key]]
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
    #
    # Transforms are given two parameters, +param+ and +context+:
    # [+param+]     transform-specific configuration from transforms.yaml
    # [+context+]
    #    [+pallet+] The pallet object being processed
    #    [+key+]    The key from transforms.yaml being processed
    #    [+value+]  Current locally assigned value for key in pallet
    #    [+abort+]  #throw this to abort transforms for current key

    def transform!(pallet)
      @key_transforms.each do |keytrans_item|
        # Enable early termination of transforms for a key
        # by wrapping execution in a catch block.
        catch do |abort_tag|
          key, transforms = keytrans_item.flatten
          context = {
            pallet: pallet,
            key:    key,
            value:  pallet[key, shallow: true],
            abort:  abort_tag
          }

          transforms.each do |t|
            transform, param = t.flatten
            if self.respond_to?(transform.to_sym) then
              if new_value = self.send(transform.to_sym, param, context)
              then
                new_value = TraceableString.new(new_value)
                new_value.file = transform.file
                new_value.line = transform.line
                new_value.column = transform.column
                new_value.byte = transform.byte
                pallet[key] = new_value
                break
              end
            end
          end
        end
      end
      @hash
    end
  end
end
