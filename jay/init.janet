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

(defn- repr
  `cast a value to a string`
  [value]
  (if (string? value) value (string/format "%q" value)))
