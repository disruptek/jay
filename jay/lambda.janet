(import spork/json)
(import curl)

(defn get-runtime-context
  `compose a runtime context from the environment`
  []
  (if-let
    [runtime-location (os/getenv "AWS_LAMBDA_RUNTIME_API")
     runtime-url (string "http://" runtime-location "/2018-06-01/runtime")]
    {:runtime-url runtime-url
     :next-url    (string runtime-url "/invocation/next")
     :handler     (os/getenv "_HANDLER")
     :directory   (os/getenv "LAMBDA_TASK_ROOT")
     :name        (os/getenv "AWS_LAMBDA_FUNCTION_NAME")
     :version     (os/getenv "AWS_LAMBDA_FUNCTION_VERSION")
     :memory      (os/getenv "AWS_LAMBDA_FUNCTION_MEMORY_SIZE")
     :log-group   (os/getenv "AWS_LAMBDA_LOG_GROUP_NAME")
     :log-stream  (os/getenv "AWS_LAMBDA_LOG_STREAM_NAME")
     :region      (os/getenv "AWS_REGION")
     }))

(defn post-event-response
  `post a response to the runtime api; returns the service reply`
  [url payload]
  (var response (buffer/new 0))
  (defn writer
    [data]
    (set response (buffer/push response data)))
  (let [encoded (json/encode payload)
        immutable (string encoded) # critically, buffer -> string
        handle (curl/easy/init)]
    (:setopt handle
             :url url
             :http-header ["content-type: application/json"]
             :post-field-size (length immutable)
             :copy-post-fields immutable
             :accept-encoding "identity"
             :write-function writer)
    (match (:perform handle)
      0 (-> response (json/decode true true) (table/to-struct))
      code (error (curl/easy/strerror code)))))

(defn- parse-one-header
  `parse a single header line`
  [str]
  (let [trimmed (string/trim str)
        [field value] (string/split ": " trimmed 0 2)
        key (string/ascii-lower field)]
    {(keyword key) value}))

(defn get-event-request
  `request an event from the runtime api`
  [url]
  (var body (buffer/new 0))
  (defn eat-body
    `callback whatfer accumulating the body`
    [data]
    (set body (buffer/push body data)))

  (var headers @{:content-type "application/json"})
  (defn eat-header
    `callback whatfer accumulating the headers`
    [data]
    (set headers
      (if (= @"\r\n" data)
        (table/to-struct headers)  # end of headers; convert to struct
        # XXX: set-cookie?
        (merge headers (parse-one-header data)))))

  # make the request
  (let [handle (curl/easy/init)]
    (:setopt handle
             :url url
             :http-header ["accept: */*"
                           "content-type: application/json"]
             :accept-encoding "" # ie. all supported encodings
             :header-function eat-header
             :write-function eat-body)
    (match (:perform handle)
      0 # success
      {:headers headers :body body}
      code (error (curl/easy/strerror code)))))

(defn parse-event
  `parse an event from the runtime api`
  [context headers body]
  (let [runtime-url (context :runtime-url)
        request-id (headers :lambda-runtime-aws-request-id)
        success-url (string/format "%s/invocation/%s/response"
                                   runtime-url request-id)
        failure-url (string/format "%s/invocation/%s/error"
                                   runtime-url request-id)]
    {:aws-request-id       request-id
     :success-url          success-url
     :failure-url          failure-url
     # date has dubious value, but it's there
     :date                 (headers :date)
     :invoked-function-arn (headers :lambda-runtime-invoked-function-arn)
     :client-context       (headers :lambda-runtime-client-context)
     :cognito-identity     (headers :lambda-runtime-cognito-identity)
     :deadline-ms          (parse (headers :lambda-runtime-deadline-ms))
     # these... exist.  so what.
     #:content-length       (parse (headers :content-length))
     #:content-type         (headers :content-type)
     :payload              body
     }))

(defn receive-event
  [context]
  (let [url (context :next-url)
        reply (get-event-request url)]
    (match reply
      {:headers headers :body body}
      {:event (parse-event context headers body)}
      uhoh (error (string/format "unexpected reply: %q" uhoh)))))
