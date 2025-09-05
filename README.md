## AWS Lambda Ruby Runtime Interface Client

We have open-sourced a set of software packages, Runtime Interface Clients (RIC), that implements the Lambda
[Runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html), allowing you to seamlessly extend
your preferred base images to be Lambda compatible.
The Lambda Runtime Interface Client is a lightweight interface that allows your runtime to
receive requests from and send requests to the Lambda service.

The Lambda Ruby Runtime Interface Client is vended through [rubygems](https://rubygems.org/gems/aws_lambda_ric). 
You can include this package in your preferred base image to make that base image Lambda compatible.

## Requirements
The Ruby Runtime Interface Client package currently supports ruby 3.0 and above.

## Migration from 2.x to 3.x

**Change**: Version 3.0.0 introduced a change in how the handler is specified:

- **Version 2.x**: Handler was passed as a command line argument
- **Version 3.x+**: Handler must be specified via the `_HANDLER` environment variable

If you're upgrading from 2.x, update your Dockerfile to use the `_HANDLER` environment variable instead of relying on `CMD` arguments.
 
## Usage

### Creating a Docker Image for Lambda with the Runtime Interface Client
First step is to choose the base image to be used. The supported Linux OS distributions are:

 - Amazon Linux 2023
 - Amazon Linux 2
 - Alpine
 - Debian
 - Ubuntu

In order to install the Runtime Interface Client, either add this line to your application's Gemfile:

```ruby
gem 'aws_lambda_ric'
```

And then execute:

    $ bundle

Or install it manually as:

    $ gem install aws_lambda_ric

The next step would be to copy your Lambda function code into the image's working directory.
You will need to set the `ENTRYPOINT` property of the Docker image to invoke the Runtime Interface Client and
set the `_HANDLER` environment variable to specify the desired handler.

**Important**: The Runtime Interface Client requires the handler to be specified via the `_HANDLER` environment variable.

Example Dockerfile:
```dockerfile
FROM amazonlinux:latest

# Define custom function directory
ARG FUNCTION_DIR="/function"

# Install ruby
RUN dnf install -y ruby3.2 make

# Install bundler
RUN gem install bundler

# Install the Runtime Interface Client
RUN gem install aws_lambda_ric

# Copy function code
RUN mkdir -p ${FUNCTION_DIR}
COPY app.rb ${FUNCTION_DIR}

WORKDIR ${FUNCTION_DIR}

# Set the handler via environment variable
ENV _HANDLER="app.App::Handler.process"

ENTRYPOINT ["/usr/local/bin/aws_lambda_ric"]
```

Note that the `ENTRYPOINT` may differ based on the base image used. You can find the correct path by running an
interactive shell in the container and checking the installed location of the gem.

```shell script
docker run -it --rm amazonlinux:latest bash
yum install -y which ruby
gem install aws_lambda_ric
which aws_lambda_ric
```

Finally, create a Ruby handler. This is an example `app.rb`:

```ruby
module App
  class Handler
    def self.process(event:, context:)
      "Hello World!"
    end
  end
end
```

### Local Testing

To make it easy to locally test Lambda functions packaged as container images we open-sourced a lightweight web-server,
Lambda Runtime Interface Emulator (RIE), which allows your function packaged as a container image to accept HTTP requests.
You can install the [AWS Lambda Runtime Interface Emulator](https://github.com/aws/aws-lambda-runtime-interface-emulator) on your local machine to test your function.
Thenm when you run the image function, you set the entrypoint to be the emulator. 

*To install the emulator and test your Lambda function*

1) From your project directory, run the following command to download the RIE from GitHub and install it on your local machine. 

```shell script
mkdir -p ~/.aws-lambda-rie && \
    curl -Lo ~/.aws-lambda-rie/aws-lambda-rie https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie && \
    chmod +x ~/.aws-lambda-rie/aws-lambda-rie
```

1) Run your Lambda image function using the docker run command. 

```shell script
docker run -d -v ~/.aws-lambda-rie:/aws-lambda -p 9000:8080 \
    -e _HANDLER="app.App::Handler.process" \
    --entrypoint /aws-lambda/aws-lambda-rie \
    myfunction:latest \
        /usr/local/bin/aws_lambda_ric
```

This runs the image as a container and starts up an endpoint locally at `http://localhost:9000/2015-03-31/functions/function/invocations`. 

1) Post an event to the following endpoint using a curl command: 

```shell script
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}'
```

This command invokes the function running in the container image and returns a response.

*Alternately, you can also include RIE as a part of your base image. See the AWS documentation on how to [Build RIE into your base image](https://docs.aws.amazon.com/lambda/latest/dg/images-test.html#images-test-alternative).*

### Automated Local Testing

For a simple approach to run your local RIC changes, use the one-command setup:

```shell script
make run-local-ric
```

This command will:
1. Build a Docker image with your local RIC code
2. Compile the gem inside the Linux container (avoiding OS compatibility issues)
3. Start the Lambda Runtime Interface Emulator on port 9000
4. Run a test Lambda function using your RIC

Once running, invoke the function from another terminal:

```shell script
curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}'
```

Modify the test handler in `test/integration/test-handlers/echo/app.rb` to test different scenarios.

## Development

### Building the package
Clone this repository and run:

```shell script
make init
make build
```

### Running tests

Make sure the project is built:
```shell script
make init build
```
Then,
* to run unit tests: `make test-unit`
* to run integration tests: `make test-integ`
* to run smoke tests: `make test-smoke`

### Troubleshooting
While running integration tests, you might encounter the Docker Hub rate limit error with the following body:
```
You have reached your pull rate limit. You may increase the limit by authenticating and upgrading: https://www.docker.com/increase-rate-limits
```
To fix the above issue, consider authenticating to a Docker Hub account by setting the Docker Hub credentials as below CodeBuild environment variables.
```shell script
DOCKERHUB_USERNAME=<dockerhub username>
DOCKERHUB_PASSWORD=<dockerhub password>
```
Recommended way is to set the Docker Hub credentials in CodeBuild job by retrieving them from AWS Secrets Manager.

## Security

If you discover a potential security issue in this project we ask that you notify AWS/Amazon Security via our [vulnerability reporting page](http://aws.amazon.com/security/vulnerability-reporting/). Please do **not** create a public github issue.

## License

This project is licensed under the Apache-2.0 License.