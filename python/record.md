some issues that i have faced - 

originally my implementation in godot went as so:
```
func _physics_process(delta: float) -> void:
	
	if peer.get_status() == peer.STATUS_CONNECTED:
		
		# wait for a message saying the python script is ready
		peer.poll()
		var _isready : String = peer.get_string(5)
		#print(ready)
		
		# first we make an observation and send to python
		var visibleTiles : Dictionary = observe()
		var visibleTilesEncoded : PackedByteArray = JSON.stringify(visibleTiles).to_utf8_buffer()
		peer.put_data(visibleTilesEncoded)
		peer.poll()
		
		# next we wait for python to respond then act based on the model's output
		# 0 = move left
		# 1 = move right
		# 2 = jump
		
		peer.poll()
		var model_action : int = peer.get_u8()
		action(delta, model_action)
		
		# finally we send back a reward to the model
		
		var model_reward : float = reward()
		peer.put_float(model_reward)
		peer.poll()
```

however i noticed that the reward will actually have to be send at the start of the frame, rather than the end
this is because the reward from the any given frame cannot be gathered until the game progresses to the next frame

-> start frame
-> gather reward
-> send to model
-> gather oberservation
-> send to model
-> next frame

I have decided to use torch-directml to handle talking to the gpu, I have done this so I can use my new 
AMD graphics card which does not support pytorch natively. DirectML uses directx12 which it does support.