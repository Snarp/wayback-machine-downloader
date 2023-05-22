# encoding: UTF-8

require 'thread'
require 'net/http'
require 'open-uri'
require 'fileutils'
require 'cgi'
require 'json'
require 'yaml'
require 'logger'
require_relative 'core_ext/string'
require_relative 'wayback_machine_downloader/version'
require_relative 'wayback_machine_downloader/archive_api'
require_relative 'wayback_machine_downloader/filtering_tools'

class WaybackMachineDownloader
  include ArchiveApi
  include FilteringTools

  attr_accessor :base_url, :exact_url, :directory, :all_timestamps,
    :from_timestamp, :to_timestamp, :only_filter, :exclude_filter, 
    :all, :maximum_pages, :threads_count, 
    :cache_lists, :logger

  # @param [String]          base_url:       nil     Base url of the website you want to retrieve as a parameter (e.g., `http://example.com`)
  # @param [String]          directory:      nil     Directory to save the downloaded files into. Default is `./websites/` plus the domain name
  # @param [String,Numeric]  from_timestamp: nil     Only files on or after timestamp supplied (ie. 20060716231334)
  # @param [String,Numeric]  to_timestamp:   nil     Only files on or before timestamp supplied (ie. 20100916231334)
  # @param [String,Regex]    only_filter:    nil     Restrict downloading to urls that include given string/match given regex
  # @param [String,Regex]    exclude_filter: nil     Skip urls that include given substring/match given regex
  # @param [TrueClass]       all:            false   Expand downloading to error files (40x and 50x) and redirections (30x)
  # @param [TrueClass]       all_timestamps: false   Download all snapshots/timestamps for a given website
  # @param [TrueClass]       exact_url:      false   Download only the url provided and not the full site
  # @param [TrueClass]       list:           false   Only list file urls in a JSON format with the archived timestamps, won't download anything
  # @param [Integer]         maximum_pages:  100     Maximum snapshot pages to consider
  # @param [Integer]         threads_count:  1       Number of files to download at a time (ie. 20)
  # @param [TrueClass]       cache_lists:    true    Whether to save local copies of fetched file lists
  # @param [Logger]          logger:         Logger.new(STDOUT)
  # @param [Hash]            **ignored_args
  def initialize(base_url:       nil, 
                 directory:      nil, 
                 from_timestamp: nil, 
                 to_timestamp:   nil, 
                 only_filter:    nil, 
                 exclude_filter: nil, 
                 all:            false, 
                 all_timestamps: false, 
                 exact_url:      false, 
                 list:           false, 
                 maximum_pages:  100, 
                 threads_count:  1, 
                 cache_lists:    true, 
                 logger:         Logger.new(STDOUT), 
                 **ignored_args)
    @base_url,@directory=base_url,directory
    @from_timestamp,@to_timestamp=from_timestamp,to_timestamp
    @only_filter,@exclude_filter=only_filter,exclude_filter
    @all,@all_timestamps,@exact_url,@list=all,all_timestamps,exact_url,list
    @maximum_pages,@threads_count=maximum_pages,threads_count
    @cache_lists,@logger=cache_lists,logger
  end

  # @return [String]
  def backup_name
    if @base_url.include? '//'
      @base_url.split('/')[2]
    else
      @base_url
    end
  end

  # @return [String]
  def backup_path
    @directory || File.join('websites', backup_name)
  end

  # @param [TrueClass] cache: @cache_lists
  # @return [Array]
  def get_all_snapshots_to_consider(cache: @cache_lists)
    # Note: Passing a page index parameter allow us to get more snapshots,
    # but from a less fresh index
    logger.info "Getting snapshot pages..."
    snapshot_list_to_consider = []
    snapshot_list_to_consider += get_raw_list_from_api(@base_url, nil)
    print "."
    if !@exact_url
      @maximum_pages.times do |page_index|
        snapshot_list = get_raw_list_from_api(@base_url + '/*', page_index)
        break if snapshot_list.empty?
        snapshot_list_to_consider += snapshot_list
        print "."
      end
    end
    logger.info "Found #{snapshot_list_to_consider.length} snaphots to consider."
    puts
    cache_list('snapshot_list_to_consider', snapshot_list_to_consider) if cache
    snapshot_list_to_consider
  end

  # @param [TrueClass] cache: @cache_lists
  # @return [Hash]
  def get_file_list_all_timestamps(cache: @cache_lists)
    file_list_curated = Hash.new
    get_all_snapshots_to_consider.each do |file_timestamp, file_url|
      next if !file_url.include?('/')
      file_id = file_url.split('/')[3..-1].join('/')
      file_id_and_timestamp = [file_timestamp, file_id].join('/')
      file_id_and_timestamp = CGI::unescape file_id_and_timestamp 
      file_id_and_timestamp = file_id_and_timestamp.tidy_bytes if file_id_and_timestamp!=""
      if file_id.nil?
        logger.info "Malformed file url, ignoring: #{file_url}"
      else
        if match_exclude_filter(file_url)
          logger.debug "File url matches exclude filter, ignoring: #{file_url}"
        elsif !match_only_filter(file_url)
          logger.debug "File url doesn't match only filter, ignoring: #{file_url}"
        elsif file_list_curated[file_id_and_timestamp]
          logger.debug "Duplicate file and timestamp combo, ignoring: #{file_id}" if @verbose
        else
          file_list_curated[file_id_and_timestamp] = {file_url: file_url, timestamp: file_timestamp}
        end
      end
    end
    logger.info "file_list_curated: " + file_list_curated.count.to_s
    cache_list('file_list_curated', file_list_curated) if cache
    file_list_curated
  end

  # @param [TrueClass] cache: @cache_lists
  # @return [Array<Hash>]
  def get_file_list_by_timestamp(cache: @cache_lists)
    @file_list_by_timestamp = if @all_timestamps
      file_list_curated = get_file_list_all_timestamps
      file_list_curated.map do |file_remote_info|
        file_remote_info[1][:file_id] = file_remote_info[0]
        file_remote_info[1]
      end
    else
      file_list_curated = get_file_list_curated
      file_list_curated = file_list_curated.sort_by { |k,v| v[:timestamp] }.reverse
      file_list_curated.map do |file_remote_info|
        file_remote_info[1][:file_id] = file_remote_info[0]
        file_remote_info[1]
      end
    end
    cache_list('file_list_by_timestamp', @file_list_by_timestamp) if cache
    return @file_list_by_timestamp
  end

  # Prints JSON-formatted list of available files to $stdout and (optionally) a local file.
  # @param [String] filename
  # @param [TrueClass] cache: @cache_lists
  # @return [Array<Hash>]
  def list_files(filename=nil, cache: @cache_lists)
    # retrieval produces its own output
    @orig_stdout = $stdout
    $stdout = $stderr
    files = file_list_by_timestamp
    if filename || cache
      filename ||= get_list_filename('file_list_by_timestamp', '.json')
      FileUtils.mkdir_p(File.dirname(filename))
      File.write(filename, files.to_json)
    end
    $stdout = @orig_stdout
    logger.info "["
    files[0...-1].each do |file|
      logger.info file.to_json + ","
    end
    logger.info files[-1].to_json
    logger.info "]"
    return files
  end

  def download_files
    start_time = Time.now
    logger.info "Downloading #{@base_url} to #{backup_path} from Wayback Machine archives."
    puts

    if file_list_by_timestamp.count == 0
      logger.warn "No files to download."
      logger.warn "Possible reasons:"
      logger.warn "\t* Site is not in Wayback Machine Archive."
      logger.warn "\t* From timestamp too much in the future." if @from_timestamp and @from_timestamp != 0
      logger.warn "\t* To timestamp too much in the past." if @to_timestamp and @to_timestamp != 0
      logger.warn "\t* Only filter too restrictive (#{only_filter.to_s})" if @only_filter
      logger.warn "\t* Exclude filter too wide (#{exclude_filter.to_s})" if @exclude_filter
      return
    end
 
    logger.info "#{file_list_by_timestamp.count} files to download:"

    threads = []
    @processed_file_count = 0
    @threads_count = 1 if @threads_count<=0
    @threads_count.times do
      threads << Thread.new do
        until file_queue.empty?
          file_remote_info = file_queue.pop(true) rescue nil
          download_file(file_remote_info) if file_remote_info
        end
      end
    end

    threads.each(&:join)
    end_time = Time.now
    puts
    logger.info "Download completed in #{(end_time - start_time).round(2)}s, saved in #{backup_path} (#{file_list_by_timestamp.size} files)"
  end

  # @param [String] dir_path
  def structure_dir_path dir_path
    begin
      FileUtils::mkdir_p dir_path unless File.exist? dir_path
    rescue Errno::EEXIST => e
      error_to_string = e.to_s
      logger.error "# #{error_to_string}"
      if error_to_string.include? "File exists @ dir_s_mkdir - "
        file_already_existing = error_to_string.split("File exists @ dir_s_mkdir - ").last
      elsif error_to_string.include? "File exists - "
        file_already_existing = error_to_string.split("File exists - ").last
      else
        msg = "Unhandled directory restructure error # #{error_to_string}"
        logger.error(msg)
        raise msg
      end
      file_already_existing_temporary = file_already_existing + '.temp'
      file_already_existing_permanent = File.join(file_already_existing, 'index.html')
      FileUtils::mv(file_already_existing, file_already_existing_temporary)
      FileUtils::mkdir_p(file_already_existing)
      FileUtils::mv(file_already_existing_temporary, file_already_existing_permanent)
      logger.warn "Moved: #{file_already_existing} -> #{file_already_existing_permanent}"
      structure_dir_path dir_path
    end
  end

  # @param [Hash] file_remote_info   ex: { file_url: http://www.example.com/img/logo.jpg, timestamp: 20150706042018, file_id: img/logo.jpg }
  def download_file(file_remote_info)
    current_encoding = "".encoding
    file_url = file_remote_info[:file_url].encode(current_encoding)

    local_path = File.join(backup_path, file_remote_info[:file_id])
    if file_url.end_with?('/') || !File.basename(local_path).include?('.')
      local_path = File.join(local_path, 'index.html')
    end

    if Gem.win_platform?
      local_path = local_path.gsub(/[:*?&=<>\|]/) {|s| '%' + s.ord.to_s(16) }
    end
    if !File.exist?(local_path)
      begin
        structure_dir_path File.dirname(local_path)
        open(local_path, "wb") do |file|
          begin
            URI("https://web.archive.org/web/#{file_remote_info[:timestamp]}id_/#{file_url}").open("Accept-Encoding" => "plain") do |uri|
              file.write(uri.read)
            end
          rescue OpenURI::HTTPError => e
            logger.error "#{file_url} # #{e}"
            if @all
              file.write(e.io.read)
              logger.debug "#{local_path} saved anyway."
            end
          rescue StandardError => e
            logger.error "#{file_url} # #{e}"
          end
        end
      rescue StandardError => e
        logger.error "#{file_url} # #{e}"
      ensure
        if !@all && File.exist?(local_path) && File.size(local_path) == 0
          File.delete(local_path)
          logger.info "#{local_path} was empty and was removed."
        end
      end
      semaphore.synchronize do
        @processed_file_count += 1
        logger.info "(#{@processed_file_count}/#{file_list_by_timestamp.size}) #{file_url} -> #{local_path}"
      end
    else # if File.exist?(local_path)
      semaphore.synchronize do
        @processed_file_count += 1
        logger.warn "(#{@processed_file_count}/#{file_list_by_timestamp.size}) #{file_url} # #{local_path} already exists."
      end
    end
  end

  # @return [Queue]
  def file_queue
    @file_queue ||= file_list_by_timestamp.each_with_object(Queue.new) { |file_info, q| q << file_info }
  end

  # @return [Array<Hash>]
  def file_list_by_timestamp
    @file_list_by_timestamp || get_file_list_by_timestamp
  end

  # @return [Mutex]
  def semaphore
    @semaphore ||= Mutex.new
  end

  # METADATA / FILE LIST CACHING

  # @param [String] name
  # @param [Array,Hash] data
  def cache_list(name, data)
    filename = get_list_filename(name)
    FileUtils.mkdir_p(File.dirname(filename))
    File.write(filename, data.to_yaml)
  end

  # @param [String] name
  # @return [Array,Hash]
  def load_list(name)
    if File.exist?(filename = get_list_filename(name))
      YAML::load(File.read(filename))
    end
  end

  # @param [String] name
  # @param [String] ext
  # @return [String]
  def get_list_filename(name, ext='.yml')
    File.join (@directory || 'websites'), "#{backup_name}_#{name}#{ext}"
  end
end
