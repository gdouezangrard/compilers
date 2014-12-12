# Compiler Design Project (Lex/Yacc)

Design a compiler for a reduced set of the C programming language.

## Usage

```
$ cat example.c
int main() {
    a = 0;
    b = 1;
    c = a + b + b;
}
```

```
$ ./parser example.c
	.text
	.globl	main
.main
	pushq	%rbp
	movq	%rsp,%rbp
	subq	$12,%rsp
	mov	$0,%eax
	mov	%eax,-4(%rbs)
	mov	$1,%eax
	mov	%eax,-8(%rbs)
	mov	-4(%rbp),%eax
	mov	-8(%rbp),%ebx
	add	%eax,%ebx
	mov	-8(%rbp),%eax
	add	%ebx,%eax
	mov	%eax,-12(%rbs)
	addq	$12,%rsp
	popq	%rbp
```

## Build

```
$ cd src
$ make
```
