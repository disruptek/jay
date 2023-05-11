(import curl)

# will allow overriding these later
(def aws_access_key_id (os/getenv "AWS_ACCESS_KEY_ID"))
(def aws_secret_access_key (os/getenv "AWS_SECRET_ACCESS_KEY"))

(defn post
  `post payload to url; returns response`
  [url payload]
  (var response (buffer/new 0))

  (defn writer [data] (set response (buffer/push response data)))

  ```
  (var request (buffer/push-string @"" payload))
  (var position 0)
  (defn reader
    `unused due to missing api for post-fields`
    [size]
    (let [ending (length request)
          remains (- ending position)
          consume (max 0 remains)
          limited (min size consume)
          future (+ position limited)]
      (if (> limited 0)
        (let [data (buffer/slice request position future)]
          (set position future)
          data)
        @"")))
  ```

  (def handle (curl/easy/init))
  (:setopt handle
           :url url
           :post? true
           :verbose? false # this is handy for debugging
           :http-header ["content-type: application/json"
                         "accept: */*"]
           :write-function writer
           :post-field-size (length payload)
           # this won't work because post-fields needs to be null
           # in order to retrieve the post data from the reader,
           # but there's no api for setting it to null explicitly
           #:read-function reader
           :copy-post-fields payload
           :accept-encoding "" # ie. all supported encodings
           :http-auth curl/http-auth-aws-sigv4
           :username aws_access_key_id
           :password aws_secret_access_key)
  (match (:perform handle)
    0 response  # success
    code (error (curl/easy/strerror code))))
