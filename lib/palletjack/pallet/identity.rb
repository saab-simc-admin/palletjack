class PalletJack < KVDAG
  class Pallet < KVDAG::Vertex

    # Represents the identity aspects of a warehouse pallet

    class Identity
      include Comparable

      # Full expanded path to this pallet
      attr_reader :path

      # Base path of the warehouse for this pallet
      attr_reader :warehouse

      # The kind of this pallet
      attr_reader :kind

      # The full name of the hierarchical parent for this pallet,
      # or nil if there is no parent.
      attr_reader :parent_name

      # The full hierarchical name for this pallet
      attr_reader :full_name

      # The leaf name for this pallet in its hierarchy
      attr_reader :leaf_name

      # Initialize identity aspects for a Pallet from components of its
      # +path+ within the +jack.warehouse+

      def initialize(jack, path)
        @warehouse = jack.warehouse
        @path = path = File.expand_path(path, @warehouse)

        path_components = []
        while path > @warehouse do
          path, part = File.split(path)
          path_components = [part, *path_components]
        end

        @kind, *path_components = path_components
        @full_name = File.join(*path_components)
        @leaf_name = path_components.last
        *path_components, _ = path_components
        @parent_name = File.join(*path_components) unless path_components.empty?
      end

      # Comparability uses the full path of the pallet

      def <=>(other)
        path <=> other.path
      end

      # Hashing uses the full path of the pallet for uniqueness

      def hash
        path.hash
      end

      # eql? must be overridden for Hash comparisons to work as expected

      alias eql? ==
    end
  end
end
