extends Node
class_name NakamaHTTPAdapter

## HTTP transport adapter for executing REST API calls against Nakama server using HTTPRequest.

func send_async(
	p_url: String,
	p_headers: PackedStringArray,
	p_method: HTTPClient.Method,
	p_body: String = "",
	p_timeout: float = 10.0
) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = p_timeout

	var err = http.request(p_url, p_headers, p_method, p_body)
	if err != OK:
		http.queue_free()
		return {
			"result": err,
			"response_code": 0,
			"headers": PackedStringArray(),
			"body": PackedByteArray(),
			"error": "Failed to initiate HTTP request: %d" % err
		}

	var res = await http.request_completed
	http.queue_free()

	return {
		"result": res[0],
		"response_code": res[1],
		"headers": res[2],
		"body": res[3],
		"error": "" if res[0] == HTTPRequest.RESULT_SUCCESS else ("HTTP request error: %d" % res[0])
	}
