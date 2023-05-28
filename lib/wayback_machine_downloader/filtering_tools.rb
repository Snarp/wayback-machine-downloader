class WaybackMachineDownloader
  module FilteringTools

    # @param [String] file_url 
    # @return [TrueClass]
    def match_only_filter file_url
      if @only_filter
        only_filter_regex = if !@only_filter.is_a?(Regexp)
          @only_filter.to_regex
        else
          @only_filter
        end
        # only_filter_regex = @only_filter.to_regex
        if only_filter_regex
          only_filter_regex =~ file_url
        else
          file_url.downcase.include? @only_filter.downcase
        end
      else
        true
      end
    end

    # @param [String] file_url 
    # @return [TrueClass]
    def match_exclude_filter file_url
      if @exclude_filter
        exclude_filter_regex = if !@exclude_filter.is_a?(Regexp)
          @exclude_filter.to_regex
        else
          @exclude_filter
        end
        # exclude_filter_regex = @exclude_filter.to_regex
        if exclude_filter_regex
          exclude_filter_regex =~ file_url
        else
          file_url.downcase.include? @exclude_filter.downcase
        end
      else
        false
      end
    end

    # @param [TrueClass] cache: @cache_lists
    # @return [Hash]   ex: { 'dirname/index.html' => { file_url: 'http://...', timestamp: '20090708105630' } }
    def get_file_list_curated(cache: @cache_lists)
      file_list_curated = Hash.new
      get_all_snapshots_to_consider.each do |file_timestamp, file_url|
        next unless file_url.include?('/')
        file_id = file_url.split('/')[3..-1].join('/')
        file_id = CGI::unescape file_id 
        file_id = file_id.tidy_bytes unless file_id == ""
        if file_id.nil?
          puts "Malformed file url, ignoring: #{file_url}"
        else
          if match_exclude_filter(file_url)
            puts "File url matches exclude filter, ignoring: #{file_url}"
          elsif not match_only_filter(file_url)
            puts "File url doesn't match only filter, ignoring: #{file_url}"
          elsif file_list_curated[file_id]
            unless file_list_curated[file_id][:timestamp] > file_timestamp
              file_list_curated[file_id] = {file_url: file_url, timestamp: file_timestamp}
            end
          else
            file_list_curated[file_id] = {file_url: file_url, timestamp: file_timestamp}
          end
        end
      end
      cache_list('file_list_curated', file_list_curated) if cache
      file_list_curated
    end
    
  end
end