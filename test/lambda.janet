(import spork/json)
(import spork/base64)
(import ../jay/aws)
(import ../jay)

(jay/aws/set-credentials)
(def arn (jay/jay-arn))

(let [data '{:hello "world"}
      encoded (string (jay/encode-json data))
      response (aws/invoke-lambda-sync arn encoded)
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
  #(assert (= true (get js :isBase64Encoded))
  #        "not base64-encoded")
  (assert (= "application/json" (get-in js [:headers :content-type]))
          "bad content type")
  (assert (deep= (jay/decode (string (json/decode (js :body)))) data)
          "bad round-trip"))

(assert (= 8 (jay/adhoc '(+ 3 5)))
        "remote exec failed")

(assert (= "side-effect" (jay/adhoc ''(string/join ["side" "effect"] "-")))
        "result recover side-effect failed")

(let [data '(+ "a" 3)
      encoded (string (jay/encode-json data))
      response (aws/invoke-lambda-sync arn encoded)
      {:ok {:headers headers :body result}} response
      js (json/decode result true true)]
  (assert (= (get js :statusCode) 400))
  (assert (= (get js :errorType) "CompileError"))
  (assert (= (get js :errorMessage) "could not find method :+ for \"a\"")))

(assert (not (nil? (jay/adhoc '(os/getenv "JANET_PATH"))))
        "expected a $JANET_PATH to be defined in jay's env")

# make sure we can import jay
(assert (nil? (jay/adhoc '(do (import jay) nil)))
        "unable to import jay from inside jay")
