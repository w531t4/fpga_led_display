# Notes
```
all: library.cpp main.cpp
```
In this case:

- `$@` evaluates to `all`
- `$<` evaluates to `library.cpp`
- `$^` evaluates to `library.cpp main.cpp`
