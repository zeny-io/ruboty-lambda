require 'ruboty/lambda'
require 'aws-sdk'

module Ruboty::Handlers
  class Lambda < Ruboty::Handlers::Base
    on /lambda list\z/,
      name: :list, description: 'List lambda functions'
    on /lambda invoke (?<fname>[a-zA-Z0-9\-_]+) (?<fjson>.*)\z/,
      name: :invoke, description: 'Invoke lambda function'

    def list(message)
      resp = aws_lambda.list_functions
      funcs = resp.functions.map do |func|
        "- #{func.function_name}"
      end

      message.reply(funcs.join("\n"), code: true)
    end

    def invoke(message)
      fn = message[:fname]
      json = message[:fjson]

      resp = aws_lambda.invoke({
        function_name: fn,
        invocation_type: "RequestResponse",
        payload: json,
        qualifier: "$LATEST",
      })

      message.reply(resp.log_result, code: true)
    end

    private

    def aws_lambda
      @aws_lambda ||= Aws::Lambda::Client.new
    end
  end
end
