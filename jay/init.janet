(import spork/base64 :as base64)
(import spork/json :as json)

#
# temporary utilities for encoding/decoding
#

(defn encode
  `encode a value to a string`
  [x]
  (base64/encode (marshal x)))

(defn decode
  `decode a value from a string`
  [x]
  (unmarshal (base64/decode x)))

(defn encode-json [value] (json/encode (encode value)))
(defn decode-json [value] (decode (json/decode value)))

(defn- repr
  `cast a value to a string`
  [value]
  (if (string? value) value (string/format "%q" value)))
