# ExecLab

Universal Code Execution System in Docker

## Using

```sh
chmod +x exec
```

### Build the Docker Image
```sh
./exec build
```

### Up the Container
```sh
./exec up
```

### Down the Container
```sh
./exec down
```

## Run Code

Write your code in `workspace/`

```sh
./exec run <language> <filename> [input-file]
```

### C++
```sh
./exec run cpp sample.cpp input1.txt
```

### Python
```sh
./exec run python sample.py input1.txt
```

### Node
```sh
./exec run node sample.js input1.txt
```

## Devcontainer

1. Up the container (after build)
2. Ctrl (command) + Shift + P > `Dev Containers: Reopen in Container`
3. Write your code in `workspace/`
4. Run in bash terminal (in VS Code) with
```sh
run_code <language> <filename> [input-file]
```