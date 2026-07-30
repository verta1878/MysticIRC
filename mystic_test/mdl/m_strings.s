	.file "m_strings.pas"
# Begin asmlist al_begin
# End asmlist al_begin
# Begin asmlist al_stabs
# End asmlist al_stabs
# Begin asmlist al_procedures

.text
	.balign 4,0x90
.globl	M_STRINGS_STRPADR$SHORTSTRING$BYTE$CHAR$$SHORTSTRING
M_STRINGS_STRPADR$SHORTSTRING$BYTE$CHAR$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$524,%esp
	movl	%eax,-4(%ebp)
	movb	%dl,-8(%ebp)
	movb	%cl,-12(%ebp)
	movl	-4(%ebp),%edx
	leal	-268(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movb	-268(%ebp),%al
	cmpb	-8(%ebp),%al
	ja	Lj5
	jmp	Lj6
Lj5:
	leal	-524(%ebp),%eax
	pushl	%eax
	movzbl	-8(%ebp),%ecx
	leal	-268(%ebp),%eax
	movl	$1,%edx
	call	fpc_shortstr_copy
	leal	-524(%ebp),%ecx
	leal	-268(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	jmp	Lj21
Lj6:
	jmp	Lj23
	.balign 4,0x90
Lj22:
	movzbl	-12(%ebp),%eax
	shll	$8,%eax
	orl	$1,%eax
	movw	%ax,-524(%ebp)
	leal	-524(%ebp),%eax
	pushl	%eax
	leal	-268(%ebp),%ecx
	leal	-268(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_concat
Lj23:
	movb	-268(%ebp),%al
	cmpb	-8(%ebp),%al
	jb	Lj22
	jmp	Lj24
Lj24:
Lj21:
	leal	-268(%ebp),%ecx
	movl	8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	leave
	ret	$4

.text
	.balign 4,0x90
.globl	M_STRINGS_STRPADC$SHORTSTRING$BYTE$CHAR$$SHORTSTRING
M_STRINGS_STRPADC$SHORTSTRING$BYTE$CHAR$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$796,%esp
	movl	%eax,-4(%ebp)
	movb	%dl,-8(%ebp)
	movb	%cl,-12(%ebp)
	movl	-4(%ebp),%edx
	leal	-270(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movb	-270(%ebp),%al
	cmpb	-8(%ebp),%al
	ja	Lj41
	jmp	Lj42
Lj41:
	movb	-8(%ebp),%al
	movb	%al,-270(%ebp)
	leal	-270(%ebp),%ecx
	movl	8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	jmp	Lj39
Lj42:
	movzbl	-270(%ebp),%edx
	movzbl	-8(%ebp),%eax
	subl	%edx,%eax
	movl	%eax,%edx
	movl	%edx,%eax
	sarl	$31,%eax
	andl	$1,%eax
	addl	%eax,%edx
	sarl	$1,%edx
	movb	%dl,-13(%ebp)
	movzbl	-13(%ebp),%eax
	shll	$1,%eax
	movzbl	-270(%ebp),%edx
	addl	%edx,%eax
	movzbl	-8(%ebp),%edx
	subl	%eax,%edx
	movl	%edx,%eax
	movb	%al,-14(%ebp)
	pushl	$2
	leal	-540(%ebp),%ecx
	movb	-13(%ebp),%dl
	movb	-12(%ebp),%al
	call	M_STRINGS_STRREP$CHAR$BYTE$$SHORTSTRING
	leal	-540(%ebp),%eax
	movl	%eax,-284(%ebp)
	leal	-270(%ebp),%eax
	movl	%eax,-280(%ebp)
	movzbl	-13(%ebp),%edx
	movzbl	-14(%ebp),%eax
	addl	%eax,%edx
	leal	-796(%ebp),%ecx
	movb	-12(%ebp),%al
	call	M_STRINGS_STRREP$CHAR$BYTE$$SHORTSTRING
	leal	-796(%ebp),%eax
	movl	%eax,-276(%ebp)
	leal	-284(%ebp),%ecx
	movl	8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_concat_multi
Lj39:
	leave
	ret	$4

.text
	.balign 4,0x90
.globl	M_STRINGS_STRPADL$SHORTSTRING$BYTE$CHAR$$SHORTSTRING
M_STRINGS_STRPADL$SHORTSTRING$BYTE$CHAR$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$528,%esp
	movl	%ebx,-528(%ebp)
	movl	%eax,-4(%ebp)
	movb	%dl,-8(%ebp)
	movb	%cl,-12(%ebp)
	movl	-4(%ebp),%edx
	leal	-524(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movb	-524(%ebp),%al
	cmpb	-8(%ebp),%al
	jae	Lj77
	jmp	Lj78
Lj77:
	movl	8(%ebp),%eax
	pushl	%eax
	movzbl	-8(%ebp),%ecx
	leal	-524(%ebp),%eax
	movl	$1,%edx
	call	fpc_shortstr_copy
	jmp	Lj87
Lj78:
	movb	-12(%ebp),%cl
	movzbl	-8(%ebp),%eax
	leal	-267(%ebp),%ebx
	movl	%eax,%edx
	movl	%ebx,%eax
	call	SYSTEM_FILLCHAR$formal$LONGINT$CHAR
	movzbl	-524(%ebp),%ecx
	movzbl	-8(%ebp),%eax
	subl	%ecx,%eax
	movl	%eax,%ecx
	leal	-268(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_setlength
	leal	-524(%ebp),%eax
	pushl	%eax
	leal	-268(%ebp),%ecx
	movl	8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_concat
Lj87:
	movl	-528(%ebp),%ebx
	leave
	ret	$4

.text
	.balign 4,0x90
.globl	M_STRINGS_STRLOWER$SHORTSTRING$$SHORTSTRING
M_STRINGS_STRLOWER$SHORTSTRING$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$272,%esp
	movl	%ebx,-272(%ebp)
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	movl	-4(%ebp),%edx
	leal	-265(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movb	-265(%ebp),%bl
	movb	$1,-9(%ebp)
	cmpb	-9(%ebp),%bl
	jb	Lj111
	decb	-9(%ebp)
	.balign 4,0x90
Lj112:
	incb	-9(%ebp)
	movzbl	-9(%ebp),%eax
	movb	-265(%ebp,%eax,1),%al
	call	M_STRINGS_LOCASE$CHAR$$CHAR
	movzbl	-9(%ebp),%edx
	movb	%al,-265(%ebp,%edx,1)
	cmpb	-9(%ebp),%bl
	ja	Lj112
Lj111:
	leal	-265(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	movl	-272(%ebp),%ebx
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRUPPER$SHORTSTRING$$SHORTSTRING
M_STRINGS_STRUPPER$SHORTSTRING$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$272,%esp
	movl	%ebx,-272(%ebp)
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	movl	-4(%ebp),%edx
	leal	-265(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movb	-265(%ebp),%bl
	movb	$1,-9(%ebp)
	cmpb	-9(%ebp),%bl
	jb	Lj126
	decb	-9(%ebp)
	.balign 4,0x90
Lj127:
	incb	-9(%ebp)
	movzbl	-9(%ebp),%eax
	movb	-265(%ebp,%eax,1),%al
	call	SYSTEM_UPCASE$CHAR$$CHAR
	movzbl	-9(%ebp),%edx
	movb	%al,-265(%ebp,%edx,1)
	cmpb	-9(%ebp),%bl
	ja	Lj127
Lj126:
	leal	-265(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	movl	-272(%ebp),%ebx
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRWIDE2STR$SHORTSTRING$BYTE$$SHORTSTRING
M_STRINGS_STRWIDE2STR$SHORTSTRING$BYTE$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$270,%esp
	movl	%eax,-4(%ebp)
	movb	%dl,-8(%ebp)
	movl	%ecx,-12(%ebp)
	movzbl	-8(%ebp),%ecx
	leal	-269(%ebp),%edx
	movl	-4(%ebp),%eax
	call	SYSTEM_MOVE$formal$formal$LONGINT
	movb	-8(%ebp),%al
	movb	%al,-270(%ebp)
	leal	-270(%ebp),%edx
	movb	$0,%al
	call	SYSTEM_POS$CHAR$SHORTSTRING$$LONGINT
	movw	%ax,-14(%ebp)
	movzwl	-14(%ebp),%eax
	cmpl	$0,%eax
	jg	Lj154
	jmp	Lj155
Lj154:
	movzwl	-14(%ebp),%eax
	decl	%eax
	movb	%al,-270(%ebp)
Lj155:
	leal	-270(%ebp),%ecx
	movl	-12(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRREP$CHAR$BYTE$$SHORTSTRING
M_STRINGS_STRREP$CHAR$BYTE$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$532,%esp
	movl	%ebx,-532(%ebp)
	movb	%al,-4(%ebp)
	movb	%dl,-8(%ebp)
	movl	%ecx,-12(%ebp)
	movb	$0,-269(%ebp)
	movb	-8(%ebp),%bl
	movb	$1,-13(%ebp)
	cmpb	-13(%ebp),%bl
	jb	Lj169
	decb	-13(%ebp)
	.balign 4,0x90
Lj170:
	incb	-13(%ebp)
	movzbl	-4(%ebp),%eax
	shll	$8,%eax
	orl	$1,%eax
	movw	%ax,-526(%ebp)
	leal	-526(%ebp),%eax
	pushl	%eax
	leal	-269(%ebp),%ecx
	leal	-269(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_concat
	cmpb	-13(%ebp),%bl
	ja	Lj170
Lj169:
	leal	-269(%ebp),%ecx
	movl	-12(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	movl	-532(%ebp),%ebx
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRZERO$LONGINT$$SHORTSTRING
M_STRINGS_STRZERO$LONGINT$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$520,%esp
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	leal	-264(%ebp),%edx
	movl	-4(%ebp),%eax
	call	M_STRINGS_STRI2S$LONGINT$$SHORTSTRING
	movzbl	-264(%ebp),%eax
	cmpl	$1,%eax
	je	Lj187
	jmp	Lj188
Lj187:
	leal	-264(%ebp),%edx
	movl	-4(%ebp),%eax
	call	M_STRINGS_STRI2S$LONGINT$$SHORTSTRING
	leal	-264(%ebp),%eax
	pushl	%eax
	movl	-8(%ebp),%eax
	movl	$_$M_STRINGS$_Ld2,%ecx
	movl	$255,%edx
	call	fpc_shortstr_concat
	jmp	Lj205
Lj188:
	leal	-264(%ebp),%eax
	pushl	%eax
	leal	-520(%ebp),%edx
	movl	-4(%ebp),%eax
	call	M_STRINGS_STRI2S$LONGINT$$SHORTSTRING
	leal	-520(%ebp),%eax
	movl	$2,%ecx
	movl	$1,%edx
	call	fpc_shortstr_copy
	leal	-264(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
Lj205:
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRCOMMA$LONGINT$$SHORTSTRING
M_STRINGS_STRCOMMA$LONGINT$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$268,%esp
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	pushl	$255
	leal	-264(%ebp),%ecx
	movl	-4(%ebp),%eax
	movl	$0,%edx
	call	fpc_shortstr_sint
	movzbl	-264(%ebp),%eax
	subl	$2,%eax
	movl	%eax,-268(%ebp)
	jmp	Lj237
	.balign 4,0x90
Lj236:
	pushl	-268(%ebp)
	leal	-264(%ebp),%edx
	movl	$255,%ecx
	movb	$44,%al
	call	SYSTEM_INSERT$CHAR$OPENSTRING$LONGINT
	subl	$3,-268(%ebp)
Lj237:
	movl	-268(%ebp),%eax
	cmpl	$1,%eax
	jg	Lj236
	jmp	Lj238
Lj238:
	leal	-264(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRH2I$SHORTSTRING$$LONGINT
M_STRINGS_STRH2I$SHORTSTRING$$LONGINT:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$272,%esp
	movl	%ebx,-272(%ebp)
	movl	%eax,-4(%ebp)
	movl	-4(%ebp),%edx
	leal	-265(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movl	$0,-8(%ebp)
	movb	$1,-9(%ebp)
	movzbl	-265(%ebp),%eax
	testl	%eax,%eax
	je	Lj259
	jmp	Lj260
Lj259:
	jmp	Lj253
Lj260:
	movb	-264(%ebp),%al
	cmpb	$36,%al
	je	Lj261
	jmp	Lj262
Lj261:
	incb	-9(%ebp)
Lj262:
	jmp	Lj264
	.balign 4,0x90
Lj263:
	movzbl	-9(%ebp),%eax
	movzbl	-265(%ebp,%eax,1),%eax
	subl	$48,%eax
	cmpl	$10,%eax
	jb	Lj268
Lj268:
	jc	Lj266
	jmp	Lj267
Lj266:
	movzbl	-9(%ebp),%eax
	movzbl	-265(%ebp,%eax,1),%edx
	subl	$48,%edx
	movl	-8(%ebp),%eax
	shll	$4,%eax
	orl	%eax,%edx
	movl	%edx,-8(%ebp)
	jmp	Lj271
Lj267:
	movzbl	-9(%ebp),%eax
	movb	-265(%ebp,%eax,1),%al
	call	SYSTEM_UPCASE$CHAR$$CHAR
	movzbl	%al,%eax
	subl	$65,%eax
	cmpl	$6,%eax
	jb	Lj276
Lj276:
	jc	Lj272
	jmp	Lj273
Lj272:
	movl	-8(%ebp),%ebx
	shll	$4,%ebx
	movzbl	-9(%ebp),%eax
	movb	-265(%ebp,%eax,1),%al
	call	SYSTEM_UPCASE$CHAR$$CHAR
	movzbl	%al,%eax
	subl	$65,%eax
	addl	$10,%eax
	orl	%eax,%ebx
	movl	%ebx,-8(%ebp)
	jmp	Lj281
Lj273:
	jmp	Lj265
Lj281:
Lj271:
	incb	-9(%ebp)
Lj264:
	movb	-265(%ebp),%al
	cmpb	-9(%ebp),%al
	jae	Lj263
	jmp	Lj265
Lj265:
Lj253:
	movl	-8(%ebp),%eax
	movl	-272(%ebp),%ebx
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRI2H$LONGINT$BYTE$$SHORTSTRING
M_STRINGS_STRI2H$LONGINT$BYTE$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$13,%esp
	movl	%eax,-4(%ebp)
	movb	%dl,-8(%ebp)
	movl	%ecx,-12(%ebp)
	movl	-12(%ebp),%ecx
	movb	-8(%ebp),%dl
	movb	$48,%al
	call	M_STRINGS_STRREP$CHAR$BYTE$$SHORTSTRING
	jmp	Lj291
	.balign 4,0x90
Lj290:
	movb	-4(%ebp),%al
	andb	$15,%al
	movzbl	%al,%eax
	addl	$48,%eax
	movb	%al,-13(%ebp)
	movb	-13(%ebp),%al
	cmpb	$57,%al
	ja	Lj295
	jmp	Lj296
Lj295:
	movb	$39,%al
	addb	%al,-13(%ebp)
Lj296:
	movl	-12(%ebp),%eax
	movzbl	-8(%ebp),%edx
	movb	-13(%ebp),%cl
	movb	%cl,(%eax,%edx,1)
	decb	-8(%ebp)
	movl	-4(%ebp),%eax
	shrl	$4,%eax
	movl	%eax,-4(%ebp)
Lj291:
	movl	-4(%ebp),%eax
	testl	%eax,%eax
	jne	Lj290
	jmp	Lj292
Lj292:
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRI2O$LONGINT$$SHORTSTRING
M_STRINGS_STRI2O$LONGINT$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$524,%esp
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	movl	-8(%ebp),%eax
	movb	$0,(%eax)
	movl	$0,-12(%ebp)
	jmp	Lj308
	.balign 4,0x90
Lj307:
	movl	-12(%ebp),%eax
	incl	%eax
	movl	%eax,-12(%ebp)
	leal	-524(%ebp),%ecx
	movb	-12(%ebp),%dl
	movl	-4(%ebp),%eax
	call	SYSTEM_OCTSTR$LONGINT$BYTE$$SHORTSTRING
	leal	-524(%ebp),%ecx
	leal	-268(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	movb	-267(%ebp),%al
	cmpb	$48,%al
	je	Lj326
	jmp	Lj325
Lj326:
	movl	-4(%ebp),%eax
	cmpl	$8,%eax
	je	Lj327
	jmp	Lj324
Lj327:
	movl	-12(%ebp),%eax
	cmpl	$1,%eax
	je	Lj325
	jmp	Lj324
Lj324:
	movzbl	-268(%ebp),%eax
	cmpl	$1,%eax
	jg	Lj328
	jmp	Lj329
Lj328:
	pushl	$1
	leal	-268(%ebp),%eax
	movl	$1,%ecx
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
Lj329:
	jmp	Lj309
Lj325:
Lj308:
	jmp	Lj307
Lj309:
	leal	-268(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRI2OCTAL$LONGINT$$SHORTSTRING
M_STRINGS_STRI2OCTAL$LONGINT$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$264,%esp
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	leal	-264(%ebp),%ecx
	movl	-4(%ebp),%eax
	movb	$40,%dl
	call	SYSTEM_OCTSTR$LONGINT$BYTE$$SHORTSTRING
	leal	-264(%ebp),%eax
	movl	-8(%ebp),%ecx
	movb	$48,%dl
	call	M_STRINGS_STRSTRIPL$SHORTSTRING$CHAR$$SHORTSTRING
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRI2OCTET$LONGINT$$SHORTSTRING
M_STRINGS_STRI2OCTET$LONGINT$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$268,%esp
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	movl	-8(%ebp),%eax
	movb	$0,(%eax)
	movl	$0,-12(%ebp)
	jmp	Lj365
	.balign 4,0x90
Lj364:
	movl	-12(%ebp),%eax
	incl	%eax
	movl	%eax,-12(%ebp)
	leal	-268(%ebp),%ecx
	movb	-12(%ebp),%dl
	movl	-4(%ebp),%eax
	call	SYSTEM_OCTSTR$LONGINT$BYTE$$SHORTSTRING
	leal	-268(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	movl	-8(%ebp),%eax
	movb	1(%eax),%al
	cmpb	$48,%al
	je	Lj383
	jmp	Lj382
Lj383:
	movl	-4(%ebp),%eax
	cmpl	$8,%eax
	je	Lj384
	jmp	Lj381
Lj384:
	movl	-12(%ebp),%eax
	cmpl	$1,%eax
	je	Lj382
	jmp	Lj381
Lj381:
	movl	-8(%ebp),%eax
	movzbl	(%eax),%eax
	cmpl	$1,%eax
	jg	Lj385
	jmp	Lj386
Lj385:
	pushl	$1
	movl	-8(%ebp),%eax
	movl	$1,%ecx
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
Lj386:
	jmp	Lj366
Lj382:
Lj365:
	jmp	Lj364
Lj366:
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRI2S$LONGINT$$SHORTSTRING
M_STRINGS_STRI2S$LONGINT$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$8,%esp
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	pushl	$255
	movl	-8(%ebp),%ecx
	movl	-4(%ebp),%eax
	movl	$-1,%edx
	call	fpc_shortstr_sint
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRR2S$REAL$BYTE$$SHORTSTRING
M_STRINGS_STRR2S$REAL$BYTE$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$8,%esp
	movb	%al,-4(%ebp)
	movl	%edx,-8(%ebp)
	fldl	8(%ebp)
	subl	$12,%esp
	fstpt	(%esp)
	movl	-8(%ebp),%eax
	pushl	%eax
	pushl	$255
	movzbl	-4(%ebp),%edx
	movl	$1,%ecx
	movl	$0,%eax
	call	fpc_shortstr_float
	leave
	ret	$8

.text
	.balign 4,0x90
.globl	M_STRINGS_STRS2I$SHORTSTRING$$INT64
M_STRINGS_STRS2I$SHORTSTRING$$INT64:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$536,%esp
	movl	%eax,-4(%ebp)
	movl	-4(%ebp),%edx
	leal	-280(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	leal	-536(%ebp),%ecx
	leal	-280(%ebp),%eax
	movb	$32,%dl
	call	M_STRINGS_STRSTRIPB$SHORTSTRING$CHAR$$SHORTSTRING
	leal	-536(%ebp),%eax
	leal	-16(%ebp),%edx
	call	fpc_val_int64_shortstr
	movl	%eax,-24(%ebp)
	movl	%edx,-20(%ebp)
	movl	-16(%ebp),%eax
	testl	%eax,%eax
	je	Lj433
	jmp	Lj434
Lj433:
	movl	-24(%ebp),%eax
	movl	%eax,-12(%ebp)
	movl	-20(%ebp),%eax
	movl	%eax,-8(%ebp)
	jmp	Lj437
Lj434:
	movl	$0,-12(%ebp)
	movl	$0,-8(%ebp)
Lj437:
	movl	-8(%ebp),%edx
	movl	-12(%ebp),%eax
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRWORDCOUNT$SHORTSTRING$CHAR$$BYTE
M_STRINGS_STRWORDCOUNT$SHORTSTRING$CHAR$$BYTE:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$266,%esp
	movl	%eax,-4(%ebp)
	movb	%dl,-8(%ebp)
	movl	-4(%ebp),%edx
	leal	-266(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movb	$0,-9(%ebp)
	movb	-8(%ebp),%al
	cmpb	$32,%al
	je	Lj444
	jmp	Lj445
Lj444:
	jmp	Lj447
	.balign 4,0x90
Lj446:
	pushl	$1
	leal	-266(%ebp),%eax
	movl	$1,%ecx
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
Lj447:
	movb	-265(%ebp),%al
	cmpb	-8(%ebp),%al
	je	Lj446
	jmp	Lj448
Lj448:
Lj445:
	movzbl	-266(%ebp),%eax
	testl	%eax,%eax
	je	Lj457
	jmp	Lj458
Lj457:
	jmp	Lj440
Lj458:
	movb	$1,-9(%ebp)
	jmp	Lj462
	.balign 4,0x90
Lj461:
	incb	-9(%ebp)
	leal	-266(%ebp),%edx
	movb	-8(%ebp),%al
	call	SYSTEM_POS$CHAR$SHORTSTRING$$LONGINT
	movb	%al,-10(%ebp)
	movb	-8(%ebp),%al
	cmpb	$32,%al
	je	Lj470
	jmp	Lj471
Lj470:
	jmp	Lj473
	.balign 4,0x90
Lj472:
	pushl	$1
	movzbl	-10(%ebp),%ecx
	leal	-266(%ebp),%eax
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
Lj473:
	movzbl	-10(%ebp),%eax
	movb	-266(%ebp,%eax,1),%al
	cmpb	-8(%ebp),%al
	je	Lj472
	jmp	Lj474
Lj474:
	jmp	Lj483
Lj471:
	pushl	$1
	movzbl	-10(%ebp),%ecx
	leal	-266(%ebp),%eax
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
Lj483:
Lj462:
	leal	-266(%ebp),%edx
	movb	-8(%ebp),%al
	call	SYSTEM_POS$CHAR$SHORTSTRING$$LONGINT
	cmpl	$0,%eax
	jg	Lj461
	jmp	Lj463
Lj463:
Lj440:
	movb	-9(%ebp),%al
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRWORDPOS$BYTE$SHORTSTRING$CHAR$$BYTE
M_STRINGS_STRWORDPOS$BYTE$SHORTSTRING$CHAR$$BYTE:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$271,%esp
	movb	%al,-4(%ebp)
	movl	%edx,-8(%ebp)
	movb	%cl,-12(%ebp)
	movl	-8(%ebp),%edx
	leal	-271(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movb	$1,-13(%ebp)
	movb	$1,-14(%ebp)
	jmp	Lj503
	.balign 4,0x90
Lj502:
	leal	-271(%ebp),%edx
	movb	-12(%ebp),%al
	call	SYSTEM_POS$CHAR$SHORTSTRING$$LONGINT
	movb	%al,-15(%ebp)
	movzbl	-15(%ebp),%eax
	testl	%eax,%eax
	je	Lj511
	jmp	Lj512
Lj511:
	jmp	Lj496
Lj512:
	movzbl	-15(%ebp),%eax
	pushl	%eax
	leal	-271(%ebp),%eax
	movl	$1,%ecx
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
	jmp	Lj522
	.balign 4,0x90
Lj521:
	pushl	$1
	leal	-271(%ebp),%eax
	movl	$1,%ecx
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
	incb	-15(%ebp)
Lj522:
	movb	-270(%ebp),%al
	cmpb	-12(%ebp),%al
	je	Lj521
	jmp	Lj523
Lj523:
	incb	-14(%ebp)
	movb	-15(%ebp),%al
	addb	%al,-13(%ebp)
Lj503:
	movb	-14(%ebp),%al
	cmpb	-4(%ebp),%al
	jb	Lj502
	jmp	Lj504
Lj504:
Lj496:
	movb	-13(%ebp),%al
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRWORDGET$BYTE$SHORTSTRING$CHAR$$SHORTSTRING
M_STRINGS_STRWORDGET$BYTE$SHORTSTRING$CHAR$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$526,%esp
	movb	%al,-4(%ebp)
	movl	%edx,-8(%ebp)
	movb	%cl,-12(%ebp)
	movl	-8(%ebp),%edx
	leal	-526(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movl	8(%ebp),%eax
	movb	$0,(%eax)
	movb	$1,-13(%ebp)
	leal	-526(%ebp),%ecx
	leal	-269(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	movb	-12(%ebp),%al
	cmpb	$32,%al
	je	Lj544
	jmp	Lj545
Lj544:
	jmp	Lj547
	.balign 4,0x90
Lj546:
	pushl	$1
	leal	-269(%ebp),%eax
	movl	$1,%ecx
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
Lj547:
	movb	-268(%ebp),%al
	cmpb	-12(%ebp),%al
	je	Lj546
	jmp	Lj548
Lj548:
Lj545:
	jmp	Lj558
	.balign 4,0x90
Lj557:
	leal	-269(%ebp),%edx
	movb	-12(%ebp),%al
	call	SYSTEM_POS$CHAR$SHORTSTRING$$LONGINT
	movb	%al,-270(%ebp)
	movzbl	-270(%ebp),%eax
	testl	%eax,%eax
	je	Lj566
	jmp	Lj567
Lj566:
	jmp	Lj532
Lj567:
	movb	-12(%ebp),%al
	cmpb	$32,%al
	je	Lj568
	jmp	Lj569
Lj568:
	jmp	Lj571
	.balign 4,0x90
Lj570:
	incb	-270(%ebp)
Lj571:
	movzbl	-270(%ebp),%eax
	movb	-269(%ebp,%eax,1),%al
	cmpb	-12(%ebp),%al
	je	Lj570
	jmp	Lj572
Lj572:
	decb	-270(%ebp)
Lj569:
	movzbl	-270(%ebp),%eax
	pushl	%eax
	leal	-269(%ebp),%eax
	movl	$1,%ecx
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
	incb	-13(%ebp)
Lj558:
	movb	-13(%ebp),%al
	cmpb	-4(%ebp),%al
	jb	Lj557
	jmp	Lj559
Lj559:
	leal	-269(%ebp),%edx
	movb	-12(%ebp),%al
	call	SYSTEM_POS$CHAR$SHORTSTRING$$LONGINT
	cmpl	$0,%eax
	jg	Lj581
	jmp	Lj582
Lj581:
	movl	8(%ebp),%eax
	pushl	%eax
	leal	-269(%ebp),%edx
	movb	-12(%ebp),%al
	call	SYSTEM_POS$CHAR$SHORTSTRING$$LONGINT
	movl	%eax,%ecx
	decl	%ecx
	leal	-269(%ebp),%eax
	movl	$1,%edx
	call	fpc_shortstr_copy
	jmp	Lj599
Lj582:
	leal	-269(%ebp),%ecx
	movl	8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
Lj599:
Lj532:
	leave
	ret	$4

.text
	.balign 4,0x90
.globl	M_STRINGS_STRSTRIPLOW$SHORTSTRING$$SHORTSTRING
M_STRINGS_STRSTRIPLOW$SHORTSTRING$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$265,%esp
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	movl	-4(%ebp),%edx
	leal	-265(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movb	$1,-9(%ebp)
	jmp	Lj611
	.balign 4,0x90
Lj610:
	movzbl	-9(%ebp),%eax
	movzbl	-265(%ebp,%eax,1),%eax
	cmpl	$32,%eax
	jb	Lj615
Lj615:
	jc	Lj613
	jmp	Lj614
Lj613:
	pushl	$1
	movzbl	-9(%ebp),%ecx
	leal	-265(%ebp),%eax
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
	jmp	Lj624
Lj614:
	incb	-9(%ebp)
Lj624:
Lj611:
	movb	-265(%ebp),%al
	cmpb	-9(%ebp),%al
	jae	Lj610
	jmp	Lj612
Lj612:
	leal	-265(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRDIZCOLOR$SHORTSTRING$$SHORTSTRING
M_STRINGS_STRDIZCOLOR$SHORTSTRING$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$1062,%esp
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	movl	-4(%ebp),%edx
	leal	-805(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movb	$0,-272(%ebp)
	movl	$1,-12(%ebp)
	movl	$7,-532(%ebp)
	movl	$0,-536(%ebp)
	movb	$0,-537(%ebp)
	jmp	Lj646
	.balign 4,0x90
Lj645:
	movzbl	-12(%ebp),%eax
	movb	-805(%ebp,%eax,1),%al
	cmpb	$27,%al
	je	Lj651
	jmp	Lj649
Lj651:
	movzbl	-805(%ebp),%eax
	cmpl	-12(%ebp),%eax
	jg	Lj650
	jmp	Lj649
Lj650:
	movl	-12(%ebp),%eax
	incl	%eax
	movzbl	%al,%eax
	movb	-805(%ebp,%eax,1),%al
	cmpb	$91,%al
	je	Lj648
	jmp	Lj649
Lj648:
	movl	-12(%ebp),%eax
	addl	$2,%eax
	movl	%eax,-16(%ebp)
	movb	$0,-528(%ebp)
	jmp	Lj657
	.balign 4,0x90
Lj656:
	movzbl	-16(%ebp),%eax
	movzbl	-805(%ebp,%eax,1),%eax
	shll	$8,%eax
	orl	$1,%eax
	movw	%ax,-1062(%ebp)
	leal	-1062(%ebp),%eax
	pushl	%eax
	leal	-528(%ebp),%ecx
	leal	-528(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_concat
	incl	-16(%ebp)
Lj657:
	movzbl	-805(%ebp),%eax
	cmpl	-16(%ebp),%eax
	jge	Lj667
	jmp	Lj658
Lj667:
	movzbl	-16(%ebp),%eax
	movzbl	-805(%ebp,%eax,1),%eax
	subl	$48,%eax
	cmpl	$10,%eax
	jb	Lj668
	cmpl	$11,%eax
	stc
	je	Lj668
	clc
Lj668:
	jc	Lj656
	jmp	Lj658
Lj658:
	movzbl	-805(%ebp),%eax
	cmpl	-16(%ebp),%eax
	jge	Lj671
	jmp	Lj670
Lj671:
	movzbl	-16(%ebp),%eax
	movb	-805(%ebp,%eax,1),%al
	cmpb	$109,%al
	je	Lj669
	jmp	Lj670
Lj669:
	movb	$0,-549(%ebp)
	movl	$1,-544(%ebp)
	jmp	Lj677
	.balign 4,0x90
Lj676:
	movl	$0,-548(%ebp)
	jmp	Lj682
	.balign 4,0x90
Lj681:
	movl	-548(%ebp),%edx
	imull	$10,%edx
	movzbl	-544(%ebp),%eax
	movzbl	-528(%ebp,%eax,1),%eax
	subl	$48,%eax
	addl	%eax,%edx
	movl	%edx,-548(%ebp)
	incl	-544(%ebp)
Lj682:
	movzbl	-528(%ebp),%eax
	cmpl	-544(%ebp),%eax
	jge	Lj686
	jmp	Lj683
Lj686:
	movzbl	-544(%ebp),%eax
	movzbl	-528(%ebp,%eax,1),%eax
	subl	$48,%eax
	cmpl	$10,%eax
	jb	Lj687
Lj687:
	jc	Lj681
	jmp	Lj683
Lj683:
	movl	-548(%ebp),%eax
	testl	%eax,%eax
	jl	Lj689
	testl	%eax,%eax
	je	Lj690
	decl	%eax
	je	Lj691
	subl	$29,%eax
	jl	Lj689
	subl	$7,%eax
	jle	Lj692
	subl	$3,%eax
	jl	Lj689
	subl	$7,%eax
	jle	Lj693
	jmp	Lj689
Lj690:
	movl	$7,-532(%ebp)
	movl	$0,-536(%ebp)
	movb	$0,-537(%ebp)
	jmp	Lj688
Lj691:
	movb	$1,-537(%ebp)
	jmp	Lj688
Lj692:
	movl	-548(%ebp),%eax
	subl	$30,%eax
	movzbl	TC_M_STRINGS_STRDIZCOLOR$SHORTSTRING$$SHORTSTRING_ANSITOMYSTIC(,%eax,1),%eax
	movl	%eax,-532(%ebp)
	jmp	Lj688
Lj693:
	movl	-548(%ebp),%eax
	subl	$40,%eax
	movzbl	TC_M_STRINGS_STRDIZCOLOR$SHORTSTRING$$SHORTSTRING_ANSITOMYSTIC(,%eax,1),%eax
	movl	%eax,-536(%ebp)
	jmp	Lj688
Lj689:
Lj688:
	movb	$1,-549(%ebp)
	movzbl	-528(%ebp),%eax
	cmpl	-544(%ebp),%eax
	jge	Lj710
	jmp	Lj709
Lj710:
	movzbl	-544(%ebp),%eax
	movb	-528(%ebp,%eax,1),%al
	cmpb	$59,%al
	je	Lj708
	jmp	Lj709
Lj708:
	incl	-544(%ebp)
Lj709:
Lj677:
	movzbl	-528(%ebp),%eax
	cmpl	-544(%ebp),%eax
	jge	Lj676
	jmp	Lj678
Lj678:
	cmpb	$0,-549(%ebp)
	jne	Lj711
	jmp	Lj712
Lj711:
	movl	%ebp,%eax
	call	M_STRINGS_STRDIZCOLOR$SHORTSTRING$$SHORTSTRING_EMITCOLOR
Lj712:
	movl	-16(%ebp),%eax
	incl	%eax
	movl	%eax,-12(%ebp)
	jmp	Lj717
Lj670:
	movl	-16(%ebp),%eax
	incl	%eax
	movl	%eax,-12(%ebp)
Lj717:
	jmp	Lj720
Lj649:
	movzbl	-12(%ebp),%eax
	movzbl	-805(%ebp,%eax,1),%eax
	cmpl	$32,%eax
	jb	Lj723
Lj723:
	jc	Lj721
	jmp	Lj722
Lj721:
	incl	-12(%ebp)
	jmp	Lj724
Lj722:
	movzbl	-12(%ebp),%eax
	movzbl	-805(%ebp,%eax,1),%eax
	shll	$8,%eax
	orl	$1,%eax
	movw	%ax,-1062(%ebp)
	leal	-1062(%ebp),%eax
	pushl	%eax
	leal	-272(%ebp),%ecx
	leal	-272(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_concat
	incl	-12(%ebp)
Lj724:
Lj720:
Lj646:
	movzbl	-805(%ebp),%eax
	cmpl	-12(%ebp),%eax
	jge	Lj645
	jmp	Lj647
Lj647:
	leal	-272(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	leave
	ret

.text
	.balign 4,0x90
M_STRINGS_STRDIZCOLOR$SHORTSTRING$$SHORTSTRING_EMITCOLOR:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$532,%esp
	movl	%eax,-4(%ebp)
	movl	-4(%ebp),%eax
	movl	-532(%eax),%eax
	movl	%eax,-8(%ebp)
	movl	-4(%ebp),%eax
	cmpb	$0,-537(%eax)
	jne	Lj741
	jmp	Lj742
Lj741:
	addl	$8,-8(%ebp)
Lj742:
	pushl	$2
	movl	-4(%ebp),%eax
	leal	-272(%eax),%eax
	movl	%eax,-20(%ebp)
	movl	$_$M_STRINGS$_Ld3,%eax
	movl	%eax,-16(%ebp)
	leal	-276(%ebp),%eax
	pushl	%eax
	movl	-8(%ebp),%eax
	addl	$100,%eax
	leal	-532(%ebp),%edx
	call	M_STRINGS_STRI2S$LONGINT$$SHORTSTRING
	leal	-532(%ebp),%eax
	movl	$2,%ecx
	movl	$2,%edx
	call	fpc_shortstr_copy
	leal	-276(%ebp),%eax
	movl	%eax,-12(%ebp)
	leal	-20(%ebp),%ecx
	movl	-4(%ebp),%eax
	leal	-272(%eax),%eax
	movl	$255,%edx
	call	fpc_shortstr_concat_multi
	pushl	$2
	movl	-4(%ebp),%eax
	leal	-272(%eax),%eax
	movl	%eax,-20(%ebp)
	movl	$_$M_STRINGS$_Ld3,%eax
	movl	%eax,-16(%ebp)
	leal	-276(%ebp),%eax
	pushl	%eax
	movl	-4(%ebp),%eax
	movl	-536(%eax),%eax
	addl	$116,%eax
	leal	-532(%ebp),%edx
	call	M_STRINGS_STRI2S$LONGINT$$SHORTSTRING
	leal	-532(%ebp),%eax
	movl	$2,%ecx
	movl	$2,%edx
	call	fpc_shortstr_copy
	leal	-276(%ebp),%eax
	movl	%eax,-12(%ebp)
	leal	-20(%ebp),%ecx
	movl	-4(%ebp),%eax
	leal	-272(%eax),%eax
	movl	$255,%edx
	call	fpc_shortstr_concat_multi
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRSTRIPPIPE$SHORTSTRING$$SHORTSTRING
M_STRINGS_STRSTRIPPIPE$SHORTSTRING$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$780,%esp
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	movl	-4(%ebp),%edx
	leal	-268(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movl	-8(%ebp),%eax
	movb	$0,(%eax)
	movb	$1,-9(%ebp)
	jmp	Lj790
	.balign 4,0x90
Lj789:
	movzbl	-9(%ebp),%eax
	movb	-268(%ebp,%eax,1),%al
	cmpb	$124,%al
	je	Lj794
	jmp	Lj793
Lj794:
	movzbl	-268(%ebp),%edx
	decl	%edx
	movzbl	-9(%ebp),%eax
	cmpl	%eax,%edx
	jg	Lj792
	jmp	Lj793
Lj792:
	leal	-524(%ebp),%eax
	pushl	%eax
	movzbl	-9(%ebp),%edx
	incl	%edx
	leal	-268(%ebp),%eax
	movl	$2,%ecx
	call	fpc_shortstr_copy
	leal	-524(%ebp),%ecx
	leal	-12(%ebp),%eax
	movl	$2,%edx
	call	fpc_shortstr_to_shortstr
	movzbl	-11(%ebp),%eax
	subl	$48,%eax
	cmpl	$10,%eax
	jb	Lj813
Lj813:
	jc	Lj812
	jmp	Lj810
Lj812:
	movzbl	-10(%ebp),%eax
	subl	$48,%eax
	cmpl	$10,%eax
	jb	Lj814
Lj814:
	jc	Lj811
	jmp	Lj810
Lj811:
	leal	-12(%ebp),%eax
	call	M_STRINGS_STRS2I$SHORTSTRING$$INT64
	cmpl	$0,%edx
	jl	Lj809
	jg	Lj810
	cmpl	$24,%eax
	jb	Lj809
	jmp	Lj810
Lj810:
	pushl	$2
	movl	-8(%ebp),%eax
	movl	%eax,-280(%ebp)
	movl	$_$M_STRINGS$_Ld3,%eax
	movl	%eax,-276(%ebp)
	leal	-12(%ebp),%ecx
	leal	-780(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	leal	-780(%ebp),%eax
	movl	%eax,-272(%ebp)
	leal	-280(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_concat_multi
Lj809:
	addb	$2,-9(%ebp)
	jmp	Lj831
Lj793:
	movzbl	-9(%ebp),%eax
	movzbl	-268(%ebp,%eax,1),%eax
	shll	$8,%eax
	orl	$1,%eax
	movw	%ax,-524(%ebp)
	leal	-524(%ebp),%eax
	pushl	%eax
	movl	-8(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_concat
Lj831:
	incb	-9(%ebp)
Lj790:
	movb	-268(%ebp),%al
	cmpb	-9(%ebp),%al
	jae	Lj789
	jmp	Lj791
Lj791:
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRSTRIPMCI$SHORTSTRING$$SHORTSTRING
M_STRINGS_STRSTRIPMCI$SHORTSTRING$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$264,%esp
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	movl	-4(%ebp),%edx
	leal	-264(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	jmp	Lj843
	.balign 4,0x90
Lj842:
	pushl	$3
	leal	-264(%ebp),%edx
	movb	$124,%al
	call	SYSTEM_POS$CHAR$SHORTSTRING$$LONGINT
	movl	%eax,%ecx
	leal	-264(%ebp),%eax
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
Lj843:
	leal	-264(%ebp),%edx
	movb	$124,%al
	call	SYSTEM_POS$CHAR$SHORTSTRING$$LONGINT
	cmpl	$0,%eax
	jg	Lj842
	jmp	Lj844
Lj844:
	leal	-264(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRMCILEN$SHORTSTRING$$BYTE
M_STRINGS_STRMCILEN$SHORTSTRING$$BYTE:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$262,%esp
	movl	%eax,-4(%ebp)
	movl	-4(%ebp),%edx
	leal	-262(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	.balign 4,0x90
Lj869:
	leal	-262(%ebp),%edx
	movb	$124,%al
	call	SYSTEM_POS$CHAR$SHORTSTRING$$LONGINT
	movb	%al,-6(%ebp)
	movzbl	-6(%ebp),%eax
	cmpl	$0,%eax
	jg	Lj880
	jmp	Lj879
Lj880:
	movzbl	-262(%ebp),%eax
	decl	%eax
	movzbl	-6(%ebp),%edx
	cmpl	%edx,%eax
	jg	Lj878
	jmp	Lj879
Lj878:
	pushl	$3
	movzbl	-6(%ebp),%ecx
	leal	-262(%ebp),%eax
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
	jmp	Lj889
Lj879:
	jmp	Lj871
Lj889:
	jmp	Lj869
Lj871:
	movb	-262(%ebp),%al
	movb	%al,-5(%ebp)
	movb	-5(%ebp),%al
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRINITIALS$SHORTSTRING$$SHORTSTRING
M_STRINGS_STRINITIALS$SHORTSTRING$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$520,%esp
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	movl	-4(%ebp),%edx
	leal	-264(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movl	-8(%ebp),%eax
	movb	$1,(%eax)
	movb	-263(%ebp),%dl
	movb	%dl,1(%eax)
	leal	-264(%ebp),%edx
	movb	$32,%al
	call	SYSTEM_POS$CHAR$SHORTSTRING$$LONGINT
	cmpl	$0,%eax
	jg	Lj896
	jmp	Lj897
Lj896:
	leal	-264(%ebp),%edx
	movb	$32,%al
	call	SYSTEM_POS$CHAR$SHORTSTRING$$LONGINT
	incl	%eax
	movzbl	%al,%eax
	movzbl	-264(%ebp,%eax,1),%eax
	shll	$8,%eax
	orl	$1,%eax
	movw	%ax,-520(%ebp)
	leal	-520(%ebp),%eax
	pushl	%eax
	movl	-8(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_concat
	jmp	Lj914
Lj897:
	movzbl	-262(%ebp),%eax
	shll	$8,%eax
	orl	$1,%eax
	movw	%ax,-520(%ebp)
	leal	-520(%ebp),%eax
	pushl	%eax
	movl	-8(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_concat
Lj914:
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRWRAP$SHORTSTRING$SHORTSTRING$BYTE$$BYTE
M_STRINGS_STRWRAP$SHORTSTRING$SHORTSTRING$BYTE$$BYTE:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$270,%esp
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	movb	%cl,-12(%ebp)
	movb	$0,-13(%ebp)
	movl	-8(%ebp),%eax
	movb	$0,(%eax)
	movl	-4(%ebp),%edx
	movb	$32,%al
	call	SYSTEM_POS$CHAR$SHORTSTRING$$LONGINT
	testl	%eax,%eax
	je	Lj929
	jmp	Lj931
Lj931:
	movl	-4(%ebp),%eax
	movb	(%eax),%al
	cmpb	-12(%ebp),%al
	jb	Lj929
	jmp	Lj930
Lj929:
	jmp	Lj923
Lj930:
	movl	-4(%ebp),%eax
	movb	(%eax),%al
	movb	%al,-14(%ebp)
	cmpb	$1,-14(%ebp)
	jb	Lj937
	incb	-14(%ebp)
	.balign 4,0x90
Lj938:
	decb	-14(%ebp)
	movl	-4(%ebp),%edx
	movzbl	-14(%ebp),%eax
	movb	(%edx,%eax,1),%al
	cmpb	$32,%al
	je	Lj941
	jmp	Lj940
Lj941:
	movb	-14(%ebp),%al
	cmpb	-12(%ebp),%al
	jb	Lj939
	jmp	Lj940
Lj939:
	leal	-270(%ebp),%eax
	pushl	%eax
	movl	-4(%ebp),%eax
	movzbl	(%eax),%ecx
	movb	-14(%ebp),%dl
	incb	%dl
	movzbl	%dl,%edx
	movl	-4(%ebp),%eax
	call	fpc_shortstr_copy
	leal	-270(%ebp),%ecx
	movl	-8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	movl	-4(%ebp),%eax
	movzbl	(%eax),%eax
	pushl	%eax
	movzbl	-14(%ebp),%ecx
	movl	-4(%ebp),%eax
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
	movb	-14(%ebp),%al
	movb	%al,-13(%ebp)
	jmp	Lj923
Lj940:
	cmpb	$1,-14(%ebp)
	ja	Lj938
Lj937:
Lj923:
	movb	-13(%ebp),%al
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRREPLACE$SHORTSTRING$SHORTSTRING$SHORTSTRING$$SHORTSTRING
M_STRINGS_STRREPLACE$SHORTSTRING$SHORTSTRING$SHORTSTRING$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$781,%esp
	movl	%eax,-4(%ebp)
	movl	%edx,-8(%ebp)
	movl	%ecx,-12(%ebp)
	movl	-4(%ebp),%edx
	leal	-269(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movl	-8(%ebp),%edx
	leal	-525(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	movl	-12(%ebp),%edx
	leal	-781(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	jmp	Lj969
	.balign 4,0x90
Lj968:
	leal	-269(%ebp),%edx
	leal	-525(%ebp),%eax
	call	SYSTEM_POS$SHORTSTRING$SHORTSTRING$$LONGINT
	movb	%al,-13(%ebp)
	movzbl	-525(%ebp),%eax
	pushl	%eax
	movzbl	-13(%ebp),%ecx
	leal	-269(%ebp),%eax
	movl	$255,%edx
	call	SYSTEM_DELETE$OPENSTRING$LONGINT$LONGINT
	movzbl	-13(%ebp),%eax
	pushl	%eax
	leal	-269(%ebp),%edx
	leal	-781(%ebp),%eax
	movl	$255,%ecx
	call	SYSTEM_INSERT$SHORTSTRING$OPENSTRING$LONGINT
Lj969:
	leal	-269(%ebp),%edx
	leal	-525(%ebp),%eax
	call	SYSTEM_POS$SHORTSTRING$SHORTSTRING$$LONGINT
	cmpl	$0,%eax
	jg	Lj968
	jmp	Lj970
Lj970:
	leal	-269(%ebp),%ecx
	movl	8(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	leave
	ret	$4

.text
	.balign 4,0x90
.globl	M_STRINGS_LOCASE$CHAR$$CHAR
M_STRINGS_LOCASE$CHAR$$CHAR:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$5,%esp
	movb	%al,-4(%ebp)
	movzbl	-4(%ebp),%eax
	subl	$65,%eax
	cmpl	$26,%eax
	jb	Lj1007
Lj1007:
	jc	Lj1005
	jmp	Lj1006
Lj1005:
	movzbl	-4(%ebp),%eax
	addl	$32,%eax
	movb	%al,-5(%ebp)
	jmp	Lj1010
Lj1006:
	movb	-4(%ebp),%al
	movb	%al,-5(%ebp)
Lj1010:
	movb	-5(%ebp),%al
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRSTRIPL$SHORTSTRING$CHAR$$SHORTSTRING
M_STRINGS_STRSTRIPL$SHORTSTRING$CHAR$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$524,%esp
	movl	%eax,-4(%ebp)
	movb	%dl,-8(%ebp)
	movl	%ecx,-12(%ebp)
	movl	-4(%ebp),%edx
	leal	-268(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	jmp	Lj1016
	.balign 4,0x90
Lj1015:
	leal	-524(%ebp),%eax
	pushl	%eax
	movzbl	-268(%ebp),%ecx
	leal	-268(%ebp),%eax
	movl	$2,%edx
	call	fpc_shortstr_copy
	leal	-524(%ebp),%ecx
	leal	-268(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
Lj1016:
	movb	-267(%ebp),%al
	cmpb	-8(%ebp),%al
	je	Lj1032
	jmp	Lj1017
Lj1032:
	movzbl	-268(%ebp),%eax
	cmpl	$0,%eax
	jg	Lj1015
	jmp	Lj1017
Lj1017:
	leal	-268(%ebp),%ecx
	movl	-12(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRSTRIPR$SHORTSTRING$CHAR$$SHORTSTRING
M_STRINGS_STRSTRIPR$SHORTSTRING$CHAR$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$268,%esp
	movl	%eax,-4(%ebp)
	movb	%dl,-8(%ebp)
	movl	%ecx,-12(%ebp)
	movl	-4(%ebp),%edx
	leal	-268(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	jmp	Lj1042
	.balign 4,0x90
Lj1041:
	decb	-268(%ebp)
Lj1042:
	movzbl	-268(%ebp),%eax
	movb	-268(%ebp,%eax,1),%al
	cmpb	-8(%ebp),%al
	je	Lj1041
	jmp	Lj1043
Lj1043:
	leal	-268(%ebp),%ecx
	movl	-12(%ebp),%eax
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRSTRIPB$SHORTSTRING$CHAR$$SHORTSTRING
M_STRINGS_STRSTRIPB$SHORTSTRING$CHAR$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$524,%esp
	movl	%eax,-4(%ebp)
	movb	%dl,-8(%ebp)
	movl	%ecx,-12(%ebp)
	movl	-4(%ebp),%edx
	leal	-268(%ebp),%ecx
	movl	$255,%eax
	call	FPC_SHORTSTR_ASSIGN
	leal	-524(%ebp),%ecx
	movb	-8(%ebp),%dl
	leal	-268(%ebp),%eax
	call	M_STRINGS_STRSTRIPL$SHORTSTRING$CHAR$$SHORTSTRING
	leal	-524(%ebp),%eax
	movl	-12(%ebp),%ecx
	movb	-8(%ebp),%dl
	call	M_STRINGS_STRSTRIPR$SHORTSTRING$CHAR$$SHORTSTRING
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_STRYN$BOOLEAN$$SHORTSTRING
M_STRINGS_STRYN$BOOLEAN$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$8,%esp
	movb	%al,-4(%ebp)
	movl	%edx,-8(%ebp)
	cmpb	$0,-4(%ebp)
	jne	Lj1066
	jmp	Lj1067
Lj1066:
	movl	-8(%ebp),%eax
	movl	$_$M_STRINGS$_Ld4,%ecx
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
	jmp	Lj1074
Lj1067:
	movl	-8(%ebp),%eax
	movl	$_$M_STRINGS$_Ld5,%ecx
	movl	$255,%edx
	call	fpc_shortstr_to_shortstr
Lj1074:
	leave
	ret

.text
	.balign 4,0x90
.globl	M_STRINGS_BYTE2HEX$BYTE$$SHORTSTRING
M_STRINGS_BYTE2HEX$BYTE$$SHORTSTRING:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$8,%esp
	movb	%al,-4(%ebp)
	movl	%edx,-8(%ebp)
	movl	-8(%ebp),%eax
	movb	$2,(%eax)
	movzbl	-4(%ebp),%eax
	shrl	$4,%eax
	movl	-8(%ebp),%edx
	movb	TC_M_STRINGS_BYTE2HEX$BYTE$$SHORTSTRING_HEXCHARS(,%eax,1),%al
	movb	%al,1(%edx)
	movb	-4(%ebp),%al
	andb	$15,%al
	movzbl	%al,%eax
	movl	-8(%ebp),%edx
	movb	TC_M_STRINGS_BYTE2HEX$BYTE$$SHORTSTRING_HEXCHARS(,%eax,1),%al
	movb	%al,2(%edx)
	leave
	ret
# End asmlist al_procedures
# Begin asmlist al_globals

.data
	.balign 4
.globl	THREADVARLIST_M_STRINGS
THREADVARLIST_M_STRINGS:
	.long	0
# End asmlist al_globals
# Begin asmlist al_const
# End asmlist al_const
# Begin asmlist al_typedconsts

.data
	.balign 4
.globl	_$M_STRINGS$_Ld1
_$M_STRINGS$_Ld1:
	.ascii	"\000\000"

.data
	.balign 4
.globl	_$M_STRINGS$_Ld2
_$M_STRINGS$_Ld2:
	.ascii	"\0010\000"

.data
TC_M_STRINGS_STRDIZCOLOR$SHORTSTRING$$SHORTSTRING_ANSITOMYSTIC:
	.byte	0,4,2,6,1,5,3,7

.data
	.balign 4
.globl	_$M_STRINGS$_Ld3
_$M_STRINGS$_Ld3:
	.ascii	"\001|\000"

.data
	.balign 4
.globl	_$M_STRINGS$_Ld4
_$M_STRINGS$_Ld4:
	.ascii	"\003Yes\000"

.data
	.balign 4
.globl	_$M_STRINGS$_Ld5
_$M_STRINGS$_Ld5:
	.ascii	"\002No\000"

.data
TC_M_STRINGS_BYTE2HEX$BYTE$$SHORTSTRING_HEXCHARS:
	.byte	48,49,50,51,52,53,54,55,56,57,97,98,99,100,101,102
# End asmlist al_typedconsts
# Begin asmlist al_rotypedconsts
# End asmlist al_rotypedconsts
# Begin asmlist al_threadvars
# End asmlist al_threadvars
# Begin asmlist al_imports
# End asmlist al_imports
# Begin asmlist al_exports
# End asmlist al_exports
# Begin asmlist al_resources
# End asmlist al_resources
# Begin asmlist al_rtti
# End asmlist al_rtti
# Begin asmlist al_dwarf_frame
# End asmlist al_dwarf_frame
# Begin asmlist al_dwarf_info
# End asmlist al_dwarf_info
# Begin asmlist al_dwarf_abbrev
# End asmlist al_dwarf_abbrev
# Begin asmlist al_dwarf_line
# End asmlist al_dwarf_line
# Begin asmlist al_picdata
# End asmlist al_picdata
# Begin asmlist al_resourcestrings
# End asmlist al_resourcestrings
# Begin asmlist al_objc_data
# End asmlist al_objc_data
# Begin asmlist al_objc_pools
# End asmlist al_objc_pools
# Begin asmlist al_end
# End asmlist al_end

