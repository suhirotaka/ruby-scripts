require 'elasticsearch'
require 'open-uri'
require 'securerandom'

class MdfileLinkElasticsearch
  def initialize
    @esc = Elasticsearch::Client.new
    
    # Set Elasticsearch index name
    @index_name = ''
    begin
      @index_name = "ruby-readme-#{SecureRandom.hex(8)}"
    end while @esc.indices.exists? index: @index_name
    puts "Set index name to #{@index_name}"

    # Set destructor
    #ObjectSpace.define_finalizer(self, self.cleanup_index)
  end
  
  def get_articles
    # Get articles from md file
    filename = './readme_test.dat'
    data = File.read(filename)
    matches = data.scan(/\[(.+?)\].*?\((.+?)\)/)
    matches.each do |match|
      title = match.first
      url = match.last
      begin
        body = open(url, &:read).encode('UTF-8')
      rescue Encoding::UndefinedConversionError => e
        puts "UndefinedConversionError occured while opening URL: #{url}"
      rescue => e
        puts "Error occured while opening URL: #{url}"
      end
      esc_res = @esc.create index: @index_name, type: 'article', body: { title: title, url: url, html_content: body }
      if esc_res['created']
        puts "Record successfully created: #{url}"
      else
        puts "Failed to create record: #{url}"
      end
      # Sleep to buffer server load
      sleep(5)
break
    end
  end
  
  def send_query
    # Query to Elasticsearch
    query = ARGV[0]
    #res = @esc.search index: @index_name, type: 'article', q: query
    res = @esc.search index: @index_name, type: 'article', body: { query: { match: { html_content: query } } }
    res['hits']['hits'].each do |article|
      puts "#{article['_source']['title']}(#{article['_source']['url']})"
    end
    cleanup_index
  end
  
  def cleanup_index
    # Cleanup the index
    esc_res = @esc.indices.delete index: @index_name
    if esc_res['acknowledged']
      puts "Index successfully removed: #{@index_name}"
    else
      puts "Failed to remove index: #{@index_name}"
    end
  end
end

md_elastic = MdfileLinkElasticsearch.new
md_elastic.get_articles
md_elastic.send_query
