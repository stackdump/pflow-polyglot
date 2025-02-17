package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"text/template"
)

const goTemplate = `package main

import (
	"fmt"
)

type State string

const (
{{- range $name, $_ := .places }}
	{{$name}} State = "{{$name}}"
{{- end }}
)

type StateVector map[State]bool

func initialState() StateVector {
	return StateVector{
{{- range $name, $place := .places }}
		{{$name}}: {{ if $place.initial }}true{{ else }}false{{ end }},
{{- end }}
	}
}

{{- range $tname, $_ := .transitions }}
func {{$tname}}(state StateVector) (StateVector, bool) {
{{- range $arc := $.arcs }}
	{{- if eq $arc.source $tname }}
        {{- if eq $arc.inhibit true }}
		if !state[{{$arc.target}}] {
			return state, false
		}
        {{- else }}
		if state[{{$arc.target}}] {
			return state, false
		}
        {{- end }}

	{{- end }}
	{{- if eq $arc.target $tname }}
        {{- if eq $arc.inhibit true }}
		if state[{{$arc.source}}] {
			return state, false
		}
        {{- else }}
		if !state[{{$arc.source}}] {
			return state, false
		}
        {{- end }}
	{{- end }}
{{- end }}
{{- range $arc := $.arcs }}
	{{- if eq $arc.source $tname }}
		state[{{$arc.target}}] = true
	{{- end }}
	{{- if eq $arc.target $tname }}
		state[{{$arc.source}}] = false
	{{- end }}
{{- end }}
	return state, true
}
{{- end }}

// executeProcess runs the transition list repeatedly until no more transitions are possible
// NOTE: This is a naive implementation provided for illustrative purposes
func executeProcess(state StateVector, transitions map[string]func(StateVector) (StateVector, bool)) StateVector {
    i := 0
    ranOne := false
    for {
		for action, transition := range transitions {
			out, ok := transition(state)
			if ok {
                i++
             
				fmt.Printf("%v: %s\n", i, action)
                state = out
				ranOne = true
				break
			}
		}
		if !ranOne {
			break
		}
		ranOne = false
	}
	return state
}

func main() {
	state := initialState()
	transitions := map[string]func(StateVector) (StateVector, bool){
{{- range $tname, $_ := .transitions }}
		"{{$tname}}": {{$tname}},
{{- end }}
	}
	finalState := executeProcess(state, transitions)
	fmt.Println("Final State:", finalState)
}
`

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run generate.go <json-file>")
		return
	}

	jsonFile, err := ioutil.ReadFile(os.Args[1])
	if err != nil {
		fmt.Println("Error reading JSON file:", err)
		return
	}

	var model map[string]interface{}
	if err := json.Unmarshal(jsonFile, &model); err != nil {
		fmt.Println("Error parsing JSON:", err)
		return
	}

	tmpl, err := template.New("code").Parse(goTemplate)
	if err != nil {
		fmt.Println("Error creating template:", err)
		return
	}

	if err := tmpl.Execute(os.Stdout, model); err != nil {
		fmt.Println("Error executing template:", err)
	}
}
