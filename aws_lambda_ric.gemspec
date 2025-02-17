# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require './lib/aws_lambda_ric/version'

Gem::Specification.new do |spec|
  spec.name                  = 'aws_lambda_ric'
  spec.version               = AwsLambdaRIC::VERSION
  spec.authors               = ['AWS Lambda']

  spec.summary               = 'AWS Lambda Runtime Interface Client for Ruby'
  spec.description           = 'The AWS Lambda Ruby Runtime Interface Client implements the Lambda programming model for Ruby.'
  spec.homepage              = 'https://github.com/aws/aws-lambda-ruby-runtime-interface-client'

  spec.license               = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.0'

  # Specify which files should be added to the gem when it is released.
  spec.files                 = %w[
    LICENSE
    README.md
    Gemfile
    NOTICE
    aws_lambda_ric.gemspec
    bin/aws_lambda_ric
  ] + Dir['lib/**/*']

  spec.bindir                = 'bin'
  # all application-style files are expected to be found in bindir
  spec.executables           = 'aws_lambda_ric'
  spec.require_paths         = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'activesupport', '~> 6.0.1'
  spec.add_development_dependency 'test-unit', '~> 3.5.5'
end
