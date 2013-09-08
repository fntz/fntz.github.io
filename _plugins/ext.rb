require "jekyll/tags"

module Jekyll 

  class CategoryAndTags < Generator
    def generate(site)
      site.tags.each do |tag|
        make_subpages(site, tag)
      end
    end


    private
    def make_subpages(site, posts) 
      posts[1] = posts[1].sort_by { |p| - p.date.to_f }     
      paginate(site,  posts)
    end

    def paginate(site, posts)
      type = "tags"
      pages = Pager.calculate_pages(posts[1], site.config['paginate'].to_i)
      (1..pages).each do |num_page|
        pager = Pager.new(site, num_page, posts[1], pages)
        path = "/#{type}/#{posts[0]}"
        if num_page > 1
          path = path + "/page#{num_page}"
        end
        newpage = GroupSubPage.new(site, site.source, path, type, posts[0])
        newpage.pager = pager
        site.pages << newpage 
      end
    end
  end

  class GroupSubPage < Page
    def initialize(site, base, dir, type, val)
      @site = site
      @base = base
      @dir = dir
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(base, '.'), "index.html")
      self.data["grouptype"] = type
      self.data[type] = val
    end
  end
end


