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
    end
    
    def initialize(key_transforms={})
      @key_transforms = key_transforms
    end
    
    def transform!(pallet)
      @pallet = pallet
      @key_transforms.each do |keytrans_item|
        key, transforms = keytrans_item.flatten
        value = @pallet[key, shallow: true]
        
        transforms.each do |transform, param|
          if self.respond_to?(transform.to_sym) then
            if new_value = self.send(transform.to_sym, value, param) then
              @pallet[key] = new_value
            end
          end
        end
      end
      @hash
    end
  end
end
