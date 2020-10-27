# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.

def echo(event:, context:)
  varname = event['varname']
  resp = ENV[varname]
  if event['match']
    pattern = event['pattern']
    if resp.match(pattern)
      {match: true}
    else
      {match: false}
    end
  else
    resp
  end
end

def env_var_is_present(event:, context:)
  ENV.key?(event['varname']).to_s
end
