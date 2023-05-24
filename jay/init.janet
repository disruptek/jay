(import spork/base64 :as base64)
(import spork/json :as json)
(import jay/aws :as aws :export true)

#
# temporary utilities for encoding/decoding
#

(defn encode
  `encode a value to a string`
  [value]
  (base64/encode (marshal value)))

(defn decode
  `decode a value from a string`
  [value]
  (unmarshal (base64/decode value)))

(defn encode-json [value] (json/encode (encode value)))
(defn decode-json [value] (decode (json/decode value)))

(defn jay-arn []
  (string/format "arn:aws:lambda:%s:%s:function:jay"
                 (aws/get-region) (aws/get-account-id)))

(defmacro adhoc
  [data]
  (let [encoded (string (encode-json data))
        arn (jay-arn)
        response (aws/invoke-lambda-sync arn encoded)
        {:ok {:headers headers :body result}} response
        js (json/decode result true true)]
    (match js
      {:errorType ty :errorMessage msg}
      (error (string/format "%s: %s" ty msg))
      {:errorMessage msg}
      (error msg)
      legit
      (let [result (decode-json (js :body))]
        result))))
