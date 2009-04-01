module Jekyll

  class Site
    attr_accessor :config, :layouts, :posts, :files, :pages, :categories
    attr_accessor :source, :dest, :lsi, :pygments, :permalink_style

    # Initialize the site
    #   +config+ is a Hash containing site configurations details
    #
    # Returns <Site>
    def initialize(config)
      self.config          = config.clone

      self.source          = config['source']
      self.dest            = config['destination']
      self.lsi             = config['lsi']
      self.pygments        = config['pygments']
      self.permalink_style = config['permalink'].to_sym

      self.layouts         = {}
      self.posts           = []
      self.pages           = []
      self.files           = []
      self.categories      = Hash.new { |hash, key| hash[key] = Array.new }

      self.setup
    end

    def setup
      # Check to see if LSI is enabled.
      require 'classifier' if self.lsi

      # Set the Markdown interpreter (and Maruku self.config, if necessary)
      case self.config['markdown']
        when 'rdiscount'
          begin
            require 'rdiscount'

            def markdown(content)
              RDiscount.new(content).to_html
            end

            puts 'Using rdiscount for Markdown'
          rescue LoadError
            puts 'You must have the rdiscount gem installed first'
          end
        when 'maruku'
          begin
            require 'maruku'

            def markdown(content)
              Maruku.new(content).to_html
            end

            if self.config['maruku']['use_divs']
              require 'maruku/ext/div'
              puts 'Maruku: Using extended syntax for div elements.'
            end

            if self.config['maruku']['use_tex']
              require 'maruku/ext/math'
              puts "Maruku: Using LaTeX extension. Images in `#{self.config['maruku']['png_dir']}`."

              # Switch off MathML output
              MaRuKu::Globals[:html_math_output_mathml] = false
              MaRuKu::Globals[:html_math_engine] = 'none'

              # Turn on math to PNG support with blahtex
              # Resulting PNGs stored in `images/latex`
              MaRuKu::Globals[:html_math_output_png] = true
              MaRuKu::Globals[:html_png_engine] =  self.config['maruku']['png_engine']
              MaRuKu::Globals[:html_png_dir] = self.config['maruku']['png_dir']
              MaRuKu::Globals[:html_png_url] = self.config['maruku']['png_url']
            end
          rescue LoadError
            puts "The maruku gem is required for markdown support!"
          end
      end
    end

    def textile(content)
      RedCloth.new(content).to_html
    end

    # Do the actual work of processing the site and generating the
    # real deal.
    #
    # Returns nothing
    def process
      print "Scanning... "
      self.scan
      print "done: #{self.posts.size} posts, "
      print "#{self.pages.size} pages, "
      print "#{self.files.size} files, and "
      print "#{self.layouts.keys.size} layouts\n"
      
      print "Transforming pages..."
      self.transform_pages
      print "done!\nCopying files..."
      self.copy_files
      print "done!\nRendering posts..."
      self.write_posts
      print "done!\n"
    end

    # Does pass through entire directory structure under <source>, sorting
    # the various files into posts, pages, and files to copy.
    #
    # Returns nothing
    def scan(dir = self.source, mode = :normal)
      return unless File.directory?(dir)

      # Switch mode based on current directory
      mode = :posts if posts_dir?(dir)
      mode = :layouts if layouts_dir?(dir)
      
      # Process each file according to mode and recursively descending directories
      # if necessary.
      filter( Dir.entries(dir) ).each do |name|
        file = File.join(dir, name)

        if File.directory?(file)
          scan(file, mode)
        elsif mode == :layouts
          layout = Layout.new(self, file)
          self.layouts[layout.name] = layout
        elsif mode == :posts && Post.valid?(file) 
          self.posts << Post.new(self, file)
        elsif page?(file)
          self.pages << Page.new(self, file)
        else
          self.files << file
        end
      end
    end

    # Test whether file is a page.
    #
    # Returns true iff file looks like it needs to be rendered
    def page?(file)
      File.open(file) { |fd| fd.read(3) } == "---"
    end

    # Get rid of files that we are ignoring: backups, hidden files, etc.
    #
    # Returns list of unrejected files
    def filter(entries) 
      entries.reject do |e|
        (not special?(e)) && ( backup?(e) || hidden?(e) || dest_dir?(e) )
      end 
    end
    
    # Number of tests for file and directory types
    def backup?(f) ; f[-1].chr == '~' ; end
    def hidden?(f) ; ['.', '_'].include?(f[0].chr) ; end
    def dest_dir?(f) ; self.dest.sub(/\/$/, '') == f ; end
    def posts_dir?(f) ; File.basename(f) == '_posts' ; end
    def layouts_dir?(f) ; File.basename(f) == '_layouts'; end
    def special?(f) ; posts_dir?(f) || layouts_dir?(f) ; end


    # Read all the files in <source>/_layouts into memory for later use.
    #
    # Returns nothing
    def read_layouts
      base = File.join(self.source, "_layouts")
      entries = []
      Dir.chdir(base) { entries = filter_entries(Dir['*.*']) }

      entries.each do |f|
        name = f.split(".")[0..-2].join(".")
        self.layouts[name] = Layout.new(self, base, f)
      end
    rescue Errno::ENOENT => e
      # ignore missing layout dir
    end

    # # Read all the files in <base>/_posts and create a new Post object with each one.
    # #
    # # Returns nothing
    # def read_posts(dir)
    #   base = File.join(self.source, dir, '_posts')
    #   entries = []
    #   Dir.chdir(base) { entries = filter_entries(Dir['**/*']) }
    # 
    #   # first pass processes, but does not yet render post content
    #   entries.each do |f|
    #     if Post.valid?(f)
    #       post = Post.new(self, self.source, dir, f)
    # 
    #       if post.published
    #         self.posts << post
    #         post.categories.each { |c| self.categories[c] << post }
    #       end
    #     end
    #   end
    # 
    #   # second pass renders each post now that full site payload is available
    #   self.posts.each do |post|
    #     post.render(self.layouts, site_payload)
    #   end
    # 
    #   self.posts.sort!
    #   self.categories.values.map { |cats| cats.sort! { |a, b| b <=> a} }
    # rescue Errno::ENOENT => e
    #   # ignore missing layout dir
    # end

    # Write each post to <dest>/<year>/<month>/<day>/<slug>
    #
    # Returns nothing
    def write_posts
      self.posts.each do |post|
        post.render(self.layouts, site_payload)
        post.write(self.dest)
      end
    end

    # Render and write out all of the marked up pages from <source> to <dest>/
    #
    # Returns nothing
    def transform_pages
      self.pages.each do |page|
          page.render(self.layouts, site_payload)
          page.write
      end
    end

    # Copy all regular files from <source> to <dest>/ 
    #
    # Returns nothing
    def copy_files
      self.files.each do |file|
        dir, name = self.relativize(file)
        FileUtils.mkdir_p(File.join(self.dest, dir))
        FileUtils.cp(file, File.join(self.dest, dir, name))        
      end
    end

    # Split the given filename relative to this site's source directory.
    #
    # Returns the directory of the file relative to site.source and its filenme
    def relativize(file)
      path, name = File.split(file)
      path =~ /^#{self.source}\/(.*)$/
      dir = $1 || ''
      
      return dir, name
    end

    # 
    # # Copy all regular files from <source> to <dest>/ ignoring
    # # any files/directories that are hidden or backup files (start
    # # with "." or "#" or end with "~") or contain site content (start with "_")
    # # unless they are "_posts" directories or web server files such as
    # # '.htaccess'
    # #   The +dir+ String is a relative path used to call this method
    # #            recursively as it descends through directories
    # #
    # # Returns nothing
    # def transform_pages(dir = '')
    #   base = File.join(self.source, dir)
    #   entries = filter_entries(Dir.entries(base))
    #   directories = entries.select { |e| File.directory?(File.join(base, e)) }
    #   files = entries.reject { |e| File.directory?(File.join(base, e)) }
    # 
    #   # we need to make sure to process _posts *first* otherwise they
    #   # might not be available yet to other templates as {{ site.posts }}
    #   if directories.include?('_posts')
    #     directories.delete('_posts')
    #     read_posts(dir)
    #   end
    #   [directories, files].each do |entries|
    #     entries.each do |f|
    #       if File.directory?(File.join(base, f))
    #         next if self.dest.sub(/\/$/, '') == File.join(base, f)
    #         transform_pages(File.join(dir, f))
    #       else
    #         first3 = File.open(File.join(self.source, dir, f)) { |fd| fd.read(3) }
    # 
    #         if first3 == "---"
    #           # file appears to have a YAML header so process it as a page
    #           page = Page.new(self, self.source, dir, f)
    #           page.render(self.layouts, site_payload)
    #           page.write(self.dest)
    #         else
    #           # otherwise copy the file without transforming it
    #           FileUtils.mkdir_p(File.join(self.dest, dir))
    #           FileUtils.cp(File.join(self.source, dir, f), File.join(self.dest, dir, f))
    #         end
    #       end
    #     end
    #   end
    # end

    # Constructs a hash map of Posts indexed by the specified Post attribute
    #
    # Returns {post_attr => [<Post>]}
    def post_attr_hash(post_attr)
      # Build a hash map based on the specified post attribute ( post attr => array of posts )
      # then sort each array in reverse order
      hash = Hash.new { |hash, key| hash[key] = Array.new }
      self.posts.each { |p| p.send(post_attr.to_sym).each { |t| hash[t] << p } }
      hash.values.map { |sortme| sortme.sort! { |a, b| b <=> a} }
      return hash
    end

    # The Hash payload containing site-wide data
    #
    # Returns {"site" => {"time" => <Time>,
    #                     "posts" => [<Post>],
    #                     "categories" => [<Post>],
    #                     "topics" => [<Post>] }}
    def site_payload
      {"site" => {
        "time" => Time.now,
        "posts" => self.posts.sort { |a,b| b <=> a },
        "categories" => post_attr_hash('categories'),
        "topics" => post_attr_hash('topics')
      }}
    end

    # # Filter out any files/directories that are hidden or backup files (start
    # # with "." or "#" or end with "~") or contain site content (start with "_")
    # # unless they are "_posts" directories or web server files such as
    # # '.htaccess'
    # def filter_entries(entries)
    #   entries = entries.reject do |e|
    #     unless ['_posts', '.htaccess'].include?(e)
    #       # Reject backup/hidden
    #       ['.', '_', '#'].include?(e[0..0]) or e[-1..-1] == '~'
    #     end
    #   end
    # end

  end
end
