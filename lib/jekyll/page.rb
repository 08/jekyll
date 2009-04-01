module Jekyll

  class Page
    include Convertible

    attr_accessor :site
    attr_accessor :ext
    attr_accessor :data, :content, :output

    # Initialize a new Page.
    #   +site+ is the Site
    #   +base+ is the String path to the <source>
    #   +dir+ is the String path between <source> and the file
    #   +name+ is the String filename of the file
    #
    # Returns <Page>
    def initialize(site, file)
      @site = site
      @file = file
      dir, name = @site.relativize(@file)
      
      self.data = {}

      self.process(name)
      self.read_yaml(@file)
    end
    
    # def initialize(site, base, dir, name)
    #   @site = site
    #   @base = base
    #   @dir = dir
    #   @name = name
    # 
    #   self.data = {}
    # 
    #   self.process(name)
    #   self.read_yaml(File.join(base, dir), name)
    #   #self.transform
    # end

    # Extract information from the page filename
    #   +name+ is the String filename of the page file
    #
    # Returns nothing
    def process(name)
      self.ext = File.extname(name)
    end

    # Add any necessary layouts to this post
    #   +layouts+ is a Hash of {"name" => "layout"}
    #   +site_payload+ is the site payload hash
    #
    # Returns nothing
    def render(layouts, site_payload)
      payload = {"page" => self.data}.deep_merge(site_payload)
      do_layout(payload, layouts)
    end

    # Write the generated page file to the destination directory.
    #   +dest+ is the String path to the destination dir
    #
    # Returns nothing
    def write
      dir, name = site.relativize(@file)
      FileUtils.mkdir_p(File.join(site.dest, dir))

      unless self.ext == ''
        name = name.split(".")[0..-2].join('.') + self.ext
      end

      path = File.join(site.dest, dir, name)
      File.open(path, 'w') do |f|
        f.write(self.output)
      end
    end
    
    # def write(dest)
    #   FileUtils.mkdir_p(File.join(dest, @dir))
    # 
    #   name = @name
    #   if self.ext != ""
    #     name = @name.split(".")[0..-2].join('.') + self.ext
    #   end
    # 
    #   path = File.join(dest, @dir, name)
    #   File.open(path, 'w') do |f|
    #     f.write(self.output)
    #   end
    # end
  end

end