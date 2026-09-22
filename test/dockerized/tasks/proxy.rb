require 'aws_lambda_ric/lambda_server'
require 'net/http'
require 'uri'

def check_proxy_bypass(event:, context:)
  original_http_proxy = ENV['HTTP_PROXY']
  original_https_proxy = ENV['HTTPS_PROXY']
  ENV['HTTP_PROXY'] = 'http://proxy.example.invalid:3128'
  ENV['HTTPS_PROXY'] = 'http://proxy.example.invalid:3128'

  uri = URI('http://169.254.100.1:9001/2018-06-01/runtime/invocation/next')

  # Baseline: a bare Net::HTTP.new (the pre-fix pattern) DOES pick up
  # HTTP_PROXY via :ENV proxy resolution for this non-loopback host.
  baseline_client = Net::HTTP.new(uri.host, uri.port)

  # Under test: RapidClient#build_client MUST NOT pick up HTTP_PROXY.
  rapid_client = RapidClient.new('169.254.100.1:9001', 'ric-proxy-regression')
  under_test = rapid_client.send(:build_client, uri)

  {
    baseline_uses_proxy: baseline_client.proxy?,
    ric_bypasses_proxy: !under_test.proxy?
  }
ensure
  ENV['HTTP_PROXY'] = original_http_proxy
  ENV['HTTPS_PROXY'] = original_https_proxy
end
