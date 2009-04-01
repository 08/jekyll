module Jekyll

  class Layout
    include Convertible

    attr_accessor :site, :name
    attr_accessor :ext
    attr_accessor :data, :content

    # Initialize a new Layout.
    #   +site+ is the Site
    #   +file+ is the File of the post file
    #
    # Returns <Page>
    def initialize(site, file)
      @name = File.basename(file).split(".")[0..-2].join(".")

      self.data = {}

      self.process(name)
      self.read_yaml(file)
    end
    
    # Extract information from the layout filename
    #   +name+ is the String filename of the layout file
    #
    # Returns nothing
    def process(name)
      self.ext = File.extname(name)
    end
  end

end