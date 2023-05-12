#!/usr/bin/env janet
(import spork/json :as json)
(import jay)
(import jay/lambda :as lambda)

(defn- repr
  `cast a value to a string`
  [value]
  (if (string? value) value (string/format "%q" value)))

(defn submit-response
  `submit a response to the lambda runtime; errors on service failure`
  [url response]
  (match (lambda/post-event-response url response)
    {:status "OK"} nil
    uhoh (error (repr uhoh))))

(defn success
  `submit a success response appropriate for api gateway`
  [{:success-url url :aws-request-id request-id} headers body]
  (submit-response url {:statusCode 200
                        :requestId request-id
                        :cookies nil # not yet
                        :multiValueHeaders nil # not yet
                        :isBase64Encoded true
                        :headers headers
                        :body body}))

(defn failure
  `submit a failure response; always returns nil`
  [{:failure-url url :aws-request-id request-id} &named code name message]
  (submit-response url {:statusCode code
                        :requestId request-id
                        :errorType name
                        :errorMessage (repr message)})
  nil)

(defn send-result-as-json
  `submit a marshal-base64-json success response`
  [event result]
  (let [headers {:content-type "application/json"
                 :x-amzn-requestid (event :aws-request-id)}
        body (jay/encode-json result)]
    (success event headers body)))

(defn process-function
  `run the user's function and submit the marshalled result encoded as json`
  [event function]
  (try
    (let [result (function)]
      (send-result-as-json event result))
    ([err] (failure event :code 400 :name "RuntimeError" :message err))))

(defn process-ast
  `compile and run the user's code, submitting a response as appropriate`
  [event ast]
  (match (compile ast (curenv) "user-code")
    {:error msg :line ln :column col}
    (failure event :code 400 :name "SyntaxError"
             :message (string/format "line %d, column %d: %s" ln col msg))
    function
    (process-function event function)))

(defn decode-or-die
  `decode an event payload or die trying`
  [event payload]
  (try
    (jay/decode-json payload)
    ([err] (failure event :code 400 :name "ValueError" :message err))))

(defn process-event
  `consume a single event and issue a response to the runtime`
  [event]
  (let [payload (event :payload)]
    # produce better error messages upon receipt of missing input
    (case payload
      nil (failure event :code 400 :name "ValueError" :message "nil payload")
      ""  (failure event :code 400 :name "ValueError" :message "empty payload")
      (if-let [ast (decode-or-die event payload)]
        (process-ast event ast)))))

(defn service-loop
  `receive and process events forever, if not sooner`
  [context]
  (let [{:event event} (lambda/receive-event context)]
    (process-event event)
    (gccollect)
    (service-loop context)))

(defn main
  [program & args]
  (let [context (lambda/get-runtime-context)]
    (service-loop context)))
