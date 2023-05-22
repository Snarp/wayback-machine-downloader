require 'json'
require 'uri'

class WaybackMachineDownloader
  module ArchiveApi

    # @param [String] url
    # @param [Integer] page_index
    # @return [Array<Array>] [["20100730171721", "http://www.site.com/"], ...]
    def get_raw_list_from_api url, page_index=nil
      request_url = URI("https://web.archive.org/cdx/search/xd")
      params = [["output", "json"], ["url", url]]
      params += parameters_for_api page_index
      request_url.query = URI.encode_www_form(params)

      begin
        json = JSON.parse(URI(request_url).open.read)
        if (json[0] <=> ["timestamp","original"]) == 0
          json.shift
        end
        json
      rescue JSON::ParserError
        []
      end
    end

    # @param [Integer] page_index
    # @return [Array<Array>]
    def parameters_for_api page_index
      parameters = [["fl", "timestamp,original"], ["collapse", "digest"], ["gzip", "false"]]
      if !@all
        parameters.push(["filter", "statuscode:200"])
      end
      if @from_timestamp and @from_timestamp != 0
        parameters.push(["from", @from_timestamp.to_s])
      end
      if @to_timestamp and @to_timestamp != 0
        parameters.push(["to", @to_timestamp.to_s])
      end
      if page_index
        parameters.push(["page", page_index])
      end
      parameters
    end

  end
end