(import spork/json :as json)
(import spork/base64 :as base64)
(import jay/aws :as aws)
(import jay)

(def account (os/getenv "AWS_ACCOUNT_ID" nil))
(assert account "define AWS_ACCOUNT_ID in your environment")

(def region (os/getenv "AWS_REGION" nil))
(assert account "define AWS_REGION in your environment")

(def jay-arn
  (string/format "arn:aws:lambda:%s:%s:function:jay" region account))

(let [data '{:hello "world"}
      encoded (string (jay/encode-json data))
      response (aws/invoke-lambda-sync jay-arn encoded)
      {:ok {:headers headers :body result}} response
      request (aws/first-header response :x-amzn-requestid)
      end-request (string/format "END RequestId: %s" request)
      logs (aws/get-lambda-log-tail response)
      js (json/decode result true true)]
  (prin logs)
  (assert (string/find end-request logs)
          "request id not found in logs")
  (assert (deep= (jay/decode (json/decode encoded)) data)
          "bad encoder/decoder")
  (assert (= 200 (get js :statusCode))
          "bad status code")
  (assert (= true (get js :isBase64Encoded))
          "not base64-encoded")
  (assert (= "application/json" (get-in js [:headers :content-type]))
          "bad content type")
  (assert (deep= (jay/decode (string (json/decode (js :body)))) data)
          "bad round-trip"))

(let [data '(+ 3 5)
      encoded (string (jay/encode-json data))
      response (aws/invoke-lambda-sync jay-arn encoded)
      {:ok {:headers headers :body result}} response
      js (json/decode result true true)]
  (assert (= 8 (jay/decode (string (json/decode (js :body)))))))

(let [data '(+ "a" 3)
      encoded (string (jay/encode-json data))
      response (aws/invoke-lambda-sync jay-arn encoded)
      {:ok {:headers headers :body result}} response
      js (json/decode result true true)]
  (assert (= (get js :statusCode) 400))
  (assert (= (get js :errorType) "CompileError"))
  (assert (= (get js :errorMessage) "could not find method :+ for \"a\"")))
