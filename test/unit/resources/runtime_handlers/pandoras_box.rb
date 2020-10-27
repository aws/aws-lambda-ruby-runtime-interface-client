# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.

def loop_a
  loop_b
end

def loop_b
  loop_a
end

def stack_overflow(_)
  loop_a
end

def hard_exit(_)
  exit(42)
end

class PandoraTest
end
