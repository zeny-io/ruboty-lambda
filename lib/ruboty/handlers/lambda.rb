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
        log_type: "Tail",
        payload: json,
        qualifier: "$LATEST",
      })

      result = Base64.decode64(resp.log_result)
      logs = []
      fields = []

      result.each_line do |line|
        case true
        when line.start_with?('START', 'END')
          next
        when line.start_with?('REPORT')
          line[7..-1].strip.split("\t").map {|f| f.split(':', 2).map(&:strip) }.each do |f|
            fields << {
              title: f[0],
              value: f[1],
              short: true
            }
          end
        else
          field = line.strip.split("\t")
          logs << "#{field[0]} #{field[2]}"
        end
      end

      payload = resp.payload.read
      fields << {
        title: "Payload",
        value: payload
      }

      success = resp.status_code >= 200 && resp.status_code <= 299

      message.reply(logs.join("\n"), code: true, attachments: [{
        color: success ? 'good' : 'danger',
        fields: fields
      }])
    end

    private

    def aws_lambda
      @aws_lambda ||= Aws::Lambda::Client.new
    end
  end
end
