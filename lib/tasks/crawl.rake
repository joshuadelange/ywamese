require 'nokogiri'
require 'open-uri'

namespace :crawl do

  desc "Crawls all websites!"
  task :all => :environment do

    # for every website
    Website.all().each do |website|

      puts "Website: #{website.url}"

      # add the website front page if wasnt added yet
      unless Page.find_by_url(website.url)

        url = website.url
        unless url.include? "http://"
          url = "http://#{url}"
        end

        Page.create!(
          :url => url.strip.gsub(" ", "%20"),
          :needs_crawling => true,
          :website_id => website.id
        ).save()

      end

      # for every page that need crawling
      website.page.where(:needs_crawling => true).find_each(:batch_size => 1) do |page|

        puts "Page: #{page.url}"

        begin
          request = open(page.url.strip.gsub("%20", ""))
        rescue OpenURI::HTTPError => the_error
          puts "Whoops got a bad status code #{the_error.message}"
          next
        end

        # skip images!
        if request.content_type.chomp.include? 'image'
          page.destroy
          next
        end

        doc = Nokogiri::HTML(request)

        # find sub pages on this website!
        doc.css("a").each do |link|

          next if link['href'] == nil

          page_url = link['href'].strip

          # lets check if url is relative (and this subpage)
          is_relative = page_url.each_char.first == '/'
          is_subpage = is_relative

          # if not relative, then check if url contains the website url
          unless is_relative
            is_subpage = /^\/|^https?:\/\/#{website.url}/.match(page_url) != nil
          end

          # if subpage, continue!
          if is_subpage

            # if relative, put the website domain in front of it
            if is_relative
              page_url = "#{website.url}#{page_url}"
            end

            # double check for http
            unless page_url.include? 'http'
              page_url = "http://#{page_url}"
            end

            # unless the page already exists...
            unless Page.find_by_url(page_url)

              puts "Added new subpage: #{page_url}"

              Page.create!(
                :url => page_url,
                :needs_crawling => true,
                :website_id => website.id
              ).save()

            end

          end

        end

        # save the words!
        number_of_words_added = 0 ;
        doc.css("h1, h2, h3, h4, h5, h6, a, p, span, li").each do |el|

          # split strings and loop over individual words
          el.content.split(' ').each do |word|

            # filtering out the bad stuff
            processed_word = word.downcase.strip.gsub(/[^a-z\s]/, '')

            # be sure we're not adding empty strings after all that filtering
            unless processed_word.empty?

              # puts "#{processed_word}\n"

              # let the word be created
              Word.create!(
                :word => processed_word,
                :original => word
              ).save()

              # just for keeping track :)
              number_of_words_added += 1

            end

          end

        end

        puts "Added new words: #{number_of_words_added}"

        # make sure we're not going over this one again later
        page.needs_crawling = false
        page.save()

      end

    end

  end

end
