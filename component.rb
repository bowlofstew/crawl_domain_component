require 'zillabyte' 
require 'zlib'
require 'anemone'

MAX_CRAWL_PAGES = 500


comp = Zillabyte.component("crawl")

# Declare the schema for inputs to the component
url_stream = comp.inputs do
  name "url_stream"
  field "url", :string
end

crawl_stream = url_stream.each do  
   execute do |tuple|
    # Init 
    url = tuple['url']
    log "crawling domain: #{url}"
    
    # Normalize the url
    begin 

      base_url = URI.parse("http://#{url.gsub(/^http(s)?:\/\//,"")}")
      max_crawl = MAX_CRAWL_PAGES
      pages_left = max_crawl
      visited = {}
      
      Anemone.crawl(base_url, :read_timeout => 10, :skip_query_strings => true) do |anemone|
  
        anemone.on_every_page do |page|
          url = page.url
          unless visited[page.url.to_s.gsub(/\/$/,'')] 
            if !page.redirect?
              visited[page.url.to_s.gsub(/\/$/,'')] = true
              log "crawling: #{page.url}"
              emit(:url => url.to_s, :html => page.body) #, :domain => url.host.to_s)  
            end
          end
        end
  
        anemone.focus_crawl do |page|
    
          if page.redirect_to
            [page.redirect_to]
            
          elsif (pages_left > 0)
    
            # Select only the links on this domain... 
            same_host_links = page.links.select do |url|
              url.host.ends_with?(base_url.host)
            end
      
            # Remove stuff we've already seen... 
            same_host_links.select! do |url|
              !visited[url.to_s.gsub(/\/$/,'')]
            end
      
            # Unique'ify
            same_host_links.uniq!
      
            # Order by size
            same_host_links.sort! do |a, b|
              a.to_s.size <=> b.to_s.size
            end
    
            # Offer urls up.. 
            next_links = same_host_links.first(pages_left)
            pages_left -= next_links.size
    
            # Done..
            next_links
      
          else
            # Done. no links.. 
            []
          end
    
        end
      end
    end

  end   
end

# Declare the output schema for the component
crawl_stream.outputs do
  name "crawl"
  field "url", :string
  field "html", :string
  #  field "domain", :string
end
