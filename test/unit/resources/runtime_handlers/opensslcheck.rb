# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.

require 'openssl'

def version(_)
  OpenSSL::OPENSSL_VERSION
end
