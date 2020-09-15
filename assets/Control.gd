extends Control

export (PackedScene) var Clickable
export (PackedScene) var Foodstuff
export (PackedScene) var Customer

onready var dialog = get_node("Dialog")

var coffee_grounds = 5
var num_cupcakes = 0
var num_bev = 0
var inventory = []
var cup_contents = []
var seats = []
var customer_line = []
var speaker
var drink = []
var current_cup_contents
var time_elapsed = 0
var someone_bought_something
var customers
var scheduled_customers = []

func _ready():
	randomize()
	var file = File.new()
	file.open('res://dialog/Characters.json', file.READ)
	var json = file.get_as_text()
	customers = JSON.parse(json).result
	file.close()
	$blackboard.hide()
	$Kitch.show()
	dialog.show()
	$backwall/coffee_grinder/object_sprite.frame = coffee_grounds
	seats = get_tree().get_nodes_in_group("seats")
	start_day()


func make_food(foodtype):
	var new_food = Foodstuff.instance()
	$backwall/coffee_grinder/object_sprite.frame = coffee_grounds
	new_food.my_type = foodtype
	new_food.connect("food_expired", self, "_on_food_expired")
	add_child(new_food)
	inventory += [new_food]
	organize_food(foodtype)


func _on_add_to_cup(item):
	$counter/cup.ingredients += [item]
	$counter/cup.add_to_drink()


func _on_add_sprite_to_cup(item):
	if not item in $counter/cup.sprite_contents:
		$counter/cup.sprite_contents += [item]
		$counter/cup.add_to_drink()


func organize_food(food_type):
	var num_cakes = 0
	num_cupcakes = 0
	num_bev = 0
	match food_type:
		"cupcake":
			for item in inventory:
				if item.my_type == food_type:
					item.position = Vector2($backwall/cupcakeholder.rect_position.x + 4 + (num_cakes % 3) * 5, $backwall/cupcakeholder.rect_position.y + 5 + int(num_cakes / 3) * 6)
					num_cakes += 1
					num_cupcakes += 1
		"coffee", "tea":
			for item in inventory:
				if item.my_type in ["coffee", "tea"]:
					item.position = Vector2($backwall/coffeeholder.rect_position.x + 3 + (num_cakes % 3) * 4, $backwall/coffeeholder.rect_position.y + 1 + int(num_cakes / 3) * 5)
					num_cakes += 1
					num_bev += 1


func _on_food_expired(food):
	inventory.erase(food)
	food.queue_free()


func _on_coffee_grinder_pressed():
	coffee_grounds = 5
	$backwall/coffee_grinder/object_sprite.frame = coffee_grounds


func _on_oven_animation_finished():
	if 6 > num_cupcakes:
		make_food("cupcake")
		$backwall/oven/object_sprite.playing = false
		$backwall/oven.ding()
		$backwall/oven/object_sprite.frame = 0


func create_customer(customer):
	var new_customer = Customer.instance()
	customer_line += [new_customer]
	new_customer.name = customer
	new_customer.add_to_group("customers")
	new_customer.progress = customers[customer]["progress"]
	new_customer.mistakes = customers[customer]["mistakes"]
	new_customer.want = customers[customer]["drink"][new_customer.progress]
	if new_customer.name == "generic":
		var which = randi() % len(customers[customer]["drink"])
		new_customer.want = customers[customer]["drink"][which]
		new_customer.progress = which # ???
	new_customer.spot_in_line = customer_line.find(new_customer)
	new_customer.target = $backwall/register
	new_customer.get_node("sprite").position = Vector2(212, 26)
	new_customer.connect("buying", self, "_on_buying")
	new_customer.connect("begin_dialog", self, "_on_dialog")
	var possible_seats = []
	for chair in seats:
		if chair.being_sat_in == false:
			possible_seats += [chair]
	possible_seats.shuffle()
	if len(possible_seats) > 0:
		new_customer.where_to_sit = possible_seats[0]
		possible_seats[0].being_sat_in = true
	else:
		new_customer.where_to_sit = null
	$backwall.add_child(new_customer)


func _on_dialog(cur_speaker, spesific_response=null):
	if spesific_response:
		dialog.initiate('%s/%s' % [cur_speaker.name, spesific_response])
	else:
		dialog.initiate('%s/%s_%s' % [cur_speaker.name, cur_speaker.name, cur_speaker.progress])
	someone_bought_something = cur_speaker.has_item
	cur_speaker.progress += 1


func _on_buying(buyer):
	if len($counter/cup.ingredients) == 16:
		var drink_made = $counter/cup.serve()
		buyer.has_item = true
		if calculate_score(drink_made, buyer.want) > 0.9:
			buyer.emit_signal("begin_dialog", buyer, "right")
			buyer.progress += 1
			buyer.upset = false
		else:
			buyer.emit_signal("begin_dialog", buyer, "wrong")
			buyer.mistakes += 1
			buyer.upset = false


func _on_advance_dialog_pressed():
	dialog.next()


func _on_cup_pressed():
	if customer_line:
		customer_line[0].emit_signal("buying", customer_line[0])


func _on_Dialog_block_ended():
	if someone_bought_something:
		if customer_line[0].where_to_sit:
			customer_line[0].change_to("going_to_table")
		else:
			customer_line[0].change_to("walking")
		customer_line.erase(customer_line[0])
		someone_bought_something = false


func calculate_score(served_drink, expected):
	if len(served_drink) != len(expected):
		return 0
	var score = 0
	for index in len(served_drink):
		if served_drink[index - 1] == expected[index - 1]:
			score += 1
	return float(score) / float(len(served_drink))


func _on_blackboard_pressed():
	for node in get_children():
		if node.is_in_group("customers"):
			node.hide()
	$blackboard.show()


func _on_x_button_pressed():
	for node in get_children():
		if node.is_in_group("customers"):
			node.show()


func _on_coffee_machine_pressed():
	if $backwall/coffee_machine/object_sprite.frame < 9:
		$backwall/coffee_machine/object_sprite.frame += 1
		$backwall/coffee_machine._on_clickable_item_pressed()
	elif coffee_grounds > 0:
		coffee_grounds -= 1
		$backwall/coffee_grinder/object_sprite.frame = coffee_grounds
		$backwall/coffee_machine/object_sprite.frame = 0


func _process(_delta):
	time_elapsed += 1
	$"character bg/sky".rect_position = Vector2(15, -766 + int(time_elapsed / 60))
	if int(time_elapsed / 60) > 766:
		end_day()
		time_elapsed = 0


func end_day():
	for customer in get_tree().get_nodes_in_group("customers"):
		customer.queue_free()
	$end_of_day.show()
	$Tween.interpolate_property($end_of_day, "color:a", 0, 1, 0.5)
	$Tween.interpolate_property($end_of_day/end_day_summary, "self_modulate:a", 0, 1, 0.5, 0, 2, 1)
	$Tween.start()


func start_day():
	scheduled_customers = customers.keys()
	scheduled_customers.shuffle()
	scheduled_customers = ["kitch"]
	print(scheduled_customers)
	while time_elapsed / 60 < 766:
		for i in scheduled_customers:
			if customers[i].has("drink"):
				if len(customer_line) == 0 and time_elapsed % 60 < 700:
					create_customer(i)
			yield(get_tree().create_timer(randi() % 25 + 5), "timeout")


func _on_end_of_day_gui_input(event):
	if event is InputEventMouseButton:
		$Tween.interpolate_property($end_of_day, "color:a", 1, 0, 0.5)
		$Tween.interpolate_property($end_of_day/end_day_summary, "self_modulate:a", 1, 0, 0.5, 0, 2)
		$Tween.start()


func _on_Control_tree_exiting():
	var file = File.new()
	file.open('res://dialog/Characters.json', file.WRITE)
	var out = to_json(customers)
	file.store_line(out)
