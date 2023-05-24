(import spork/base64 :as base64)
(import curl)

(defn default-credentials
  []
  @{:aws-access-key-id (os/getenv "AWS_ACCESS_KEY_ID")
    :aws-secret-access-key (os/getenv "AWS_SECRET_ACCESS_KEY")
    :aws-account-id (os/getenv "AWS_ACCOUNT_ID")
    :aws-region (os/getenv "AWS_REGION")})

(defn set-credentials
  [&opt creds]
  (default creds (default-credentials))
  (let [current (dyn :aws-credentials @{})]
    (setdyn :aws-credentials (merge current creds))))

(defn get-region [] ((dyn :aws-credentials) :aws-region))
(defn get-account-id [] ((dyn :aws-credentials) :aws-account-id))

(defn explode-arn
  `decompose an arn into its parts`
  [arn]
  (let [parts (string/split ":" arn 0 6)]
    {
     #:arn     (0 parts)
     #:aws     (1 parts)
     :service  (2 parts)
     :region   (3 parts)
     :account  (4 parts)
     :resource (5 parts)  # might include further : or /
    }))

(def- http-grammar
  `modified from the spork version to support http/2 absent message`
  ~{:http-version (* "HTTP/" :d+ (? (* "." :d+)))
    :request-status (* :method :ws :path :ws :http-version :any-ws :rn)
    :response-status (* :http-version :ws (/ ':d+ ,scan-number)
                        :ws '(any :printable) :rn)
    :ws (some (set " \t"))
    :any-ws (any (set " \t"))
    :rn "\r\n"
    :method '(some (range "AZ"))
    :path-chr (range "az" "AZ" "09" "!!" "$9" ":;" "==" "?@" "~~" "__")
    :path '(some :path-chr)
    :printable (range "\x20~" "\t\t")
    :headers (* (any :header) :rn)
    # lower case header names since http headers are case-insensitive
    :header-name (/ '(some (range "\x219" ";~")) ,string/ascii-lower)
    :header-value '(any :printable)
    :header (* :header-name ":" :any-ws :header-value :rn)})

(def request-peg
  "PEG for parsing HTTP requests"
  (peg/compile
    (table/to-struct
      (merge {:main ~(* :request-status :headers)}
             http-grammar))))

(def response-peg
  "PEG for parsing HTTP responses"
  (peg/compile
    (table/to-struct
      (merge {:main ~(* :response-status :headers)}
             http-grammar))))

(defn parse-headers
  [inputs]
  (match inputs
    [header value & tail]
    (let [result (parse-headers tail)
          name (keyword header)
          existing (get result name @[])]
      (put result name (array/concat @[value] existing)))
    _ @{}))

(defn parse-preamble
  `decompose a response preamble into status+message, headers`
  [preamble]
  (let [[status message & headers] (peg/match response-peg preamble)
        headers (table/to-struct (parse-headers headers))]
    {:status status :message message :headers headers}))

(defn post
  `post payload to url; returns response`
  [payload &named headers url]
  (unless (string? payload)
    (error "payload must be a string"))

  # probably a fair assumption; i'm too lazy to omit
  # the headers argument from the set-opt call later
  (def headers (or headers ["content-type: application/json"]))

  (var body (buffer/new 0))
  (defn eat-body [data] (set body (buffer/push body data)))

  (var preamble (buffer/new 1024))
  (defn eat-header
    `callback whatfer accumulating the status and headers`
    [data]
    (buffer/push preamble data))

  (def creds (dyn :aws-credentials))
  (def handle (curl/easy/init))
  (:setopt handle
           :url url
           :post? true
           :verbose? false # this is handy for debugging
           :http-header headers
           :post-field-size (length payload)
           # this won't work because post-fields needs to be null
           # in order to retrieve the post data from the reader,
           # but there's no api for setting it to null explicitly
           #:read-function reader
           :copy-post-fields payload
           :accept-encoding "" # ie. all supported encodings
           :http-auth curl/http-auth-aws-sigv4
           :username (creds :aws-access-key-id)
           :password (creds :aws-secret-access-key)
           :header-function eat-header
           :write-function eat-body)
  (match (:perform handle)
    0
    (let [{:status status :message message :headers headers}
           (parse-preamble preamble)]
      {:ok {:status status :message message :headers headers :body body}})
    code
    {:error (curl/easy/strerror code)}))

(defn lambda-arn-to-endpoint
  `convert a lambda arn to an endpoint url`
  [arn]
  (let [arn (explode-arn arn)
        host (string "lambda." (arn :region) ".amazonaws.com")
        name (last (string/split ":" (arn :resource))) # omit function:
        path (string/format "/2015-03-31/functions/%s/invocations" name)
        url (string "https://" host path)]
    url))

(defn invoke-lambda-sync
  `post payload to lambda function synchronously`
  [arn payload]
  (let [url (lambda-arn-to-endpoint arn)
        headers ["content-type: application/x-amz-json-1.1"
                 "x-amz-log-type: Tail"
                 "accept: */*"]]
    (post payload :url url :headers headers)))

(defn first-header
  `get the first value of a header in a lambda response`
  [response name]
  (if-let [headers (get-in response [:ok :headers name])]
    (first headers)))

(defn get-lambda-log-tail
  `get the log tail from a lambda response`
  [response]
  (if-let [log (first-header response :x-amz-log-result)
           log (base64/decode log)]
    log))
