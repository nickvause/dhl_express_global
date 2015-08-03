def dhl_credentials
  @dhl_credentials ||= credentials["development"]
end

def dhl_production_credentials
  @dhl_production_credentials ||= credentials["production"]
end

private

def credentials
  @credentials ||= YAML.load_file(credentials_path)
end

def credentials_path
  File.expand_path("../../config/dhl_credentials.yml", __FILE__)
end