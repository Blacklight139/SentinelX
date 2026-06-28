package client

import (
	"encoding/json"
	"io"
)

// decodeJSON decodes JSON from an io.Reader.
func decodeJSON(r io.Reader, v interface{}) error {
	return json.NewDecoder(r).Decode(v)
}
