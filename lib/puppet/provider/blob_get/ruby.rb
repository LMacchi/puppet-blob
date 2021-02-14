Puppet::Type.type(:blob_get).provide(:get) do
  desc 'Retrieves an object from Azure Blob storage'

  def create
    metadata_uri = URI('http://169.254.169.254')
    connection = Net::HTTP.new(metadata_uri.host, metadata_uri.port)

    header = { 'Metadata' => 'true' }
    request_and_headers = Net::HTTP::Get.new("/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2F#{@resource[:account]}.blob.core.windows.net%2F&client_id=#{@resource[:client_id]}", header)

    response = connection.request(request_and_headers)
    token = JSON.parse(response.body)['access_token']

    if token.nil?
      raise Puppet::Error, 'No token received from Azure metadata service.'
    end

    blob_uri = URI("https://#{@resource[:account]}.blob.core.windows.net/#{@resource[:blob_path]}")

    Net::HTTP.start(blob_uri.host, blob_uri.port, :use_ssl => blob_uri.scheme == 'https') do |http|
      header = { 'Authorization' => "Bearer #{token}", 'x-ms-version' => '2017-11-09' }
      request = Net::HTTP::Get.new(blob_uri, header)
      http.request(request) do |response|
        if response.code != '200'
          raise Puppet::Error, "#{response.code}"
        end
        open("#{@resource[:path]}", 'wb') do |file|
          response.read_body do |chunk|
            file.write(chunk)
          end
        end
      end
    end
    #if Puppet::Util::Platform.windows?
    #  Puppet::Util::Windows::Security.set_mode(@resource[:mode], Puppet::FileSystem.path_string(@resource[:path]))
    #else
    #  FileUtils.chmod(@resource[:mode], Puppet::FileSystem.path_string(@resource[:path]))
    #end
  end

  def destroy
    File.unlink(@resource[:path])
  end

  def exists?
    File.exist?(@resource[:path])
  end
end