extends Object

var _processor: Thread
var _queue_functions: Array[Callable]
var _queue_paremeters: Array[Array]
var _queue_mutex: Mutex
var _continue: bool

func start() -> void:
	_continue = true
	_queue_mutex = Mutex.new()
	_processor = Thread.new()
	_processor.start(_loop)

func finish() -> void:
	_continue = false
	if _processor and _processor.is_alive():
		_processor.wait_to_finish()

func add_to_line(fn: Callable, ...args: Array) -> void:
	_queue_mutex.lock()
	_queue_functions.append(fn)
	_queue_paremeters.append(args)
	_queue_mutex.unlock()

func _loop() -> void:
	while _continue:
		_queue_mutex.lock()
		var fn: Callable = _queue_functions.pop_front()
		var args: Array = _queue_paremeters.pop_front()
		_queue_mutex.unlock()
		if fn: fn.call(args)
