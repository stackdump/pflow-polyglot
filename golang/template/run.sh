echo "bool based state machine"
echo "========================"
go run generate_elementary.go model.json | gofmt > coffee_machine_bool.go
go run coffee_machine_bool.go

echo "int64 based state machine"
echo "========================"
go run generate.go model.json | gofmt > coffee_machine_int64.go
go run coffee_machine_int64.go
