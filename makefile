SRC = src/main.pas
OUT = ./bin/app

FPC = fpc
FPC_FLAGS = -O4

compile:
	$(FPC) $(FPC_FLAGS) $(SRC) -o$(OUT)

./bin:
	mkdir -p bin

clean:
	rm -r ./bin/*

all:
	@echo compile, clean
