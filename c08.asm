         ;代码清单8-2
         ;文件名：c08.asm
         ;文件说明：用户程序 
         ;创建日期：2011-5-5 18:17
         
;===============================================================================
SECTION header vstart=0                     ;定义用户程序头部段 
    program_length  dd program_end          ;程序总长度[0x00]
    
    ;用户程序入口点
    code_entry      dw start                ;偏移地址[0x04]
                    dd section.code_1.start ;段地址[0x06] 
    
    realloc_tbl_len dw (header_end-code_1_segment)/4
                                            ;段重定位表项个数[0x0a]
    
    ;段重定位表           
    code_1_segment  dd section.code_1.start ;[0x0c]
    code_2_segment  dd section.code_2.start ;[0x10]
    data_1_segment  dd section.data_1.start ;[0x14]
    data_2_segment  dd section.data_2.start ;[0x18]
    stack_segment   dd section.stack.start  ;[0x1c]
    
    header_end:                
    
;===============================================================================
SECTION code_1 align=16 vstart=0         ;定义代码段1（16字节对齐） 
put_string:                              ;显示串(0结尾)。
                                         ;输入：DS:BX=串地址
         mov cl,[bx]
         or cl,cl                        ;cl=0 ?如果cl是0则跳转到37行
         jz .exit                        ;是0，返回主程序 
         call put_char
         inc bx                          ;下一个字符 
         jmp put_string

   .exit:
         ret

;-------------------------------------------------------------------------------
put_char:                                ;显示一个字符
                                         ;输入：cl=字符ascii
         push ax
         push bx
         push cx
         push dx
         push ds
         push es

         ;以下取当前光标位置：从0x0e号寄存器读出光标位置的高8位，从0x0f号寄存器读出光标位置的低8位，组合成光标的位置存放到bx
         mov dx,0x3d4
         mov al,0x0e
         out dx,al						;通过索引端口0x3d4，通知显卡现在要操作0x0e号寄存器
         mov dx,0x3d5					;通过数据端口0x3d5，从0x0e号寄存器读出一个子节的数据存放到al
         in al,dx                        ;高8位 
         mov ah,al

         mov dx,0x3d4
         mov al,0x0f
         out dx,al						;通过索引端口0x3d4，通知显卡现在要操作0x0f号寄存器
         mov dx,0x3d5					;通过数据端口0x3d5，从0x0f号寄存器读出一个子节的数据存放到al
         in al,dx                        ;低8位 
         mov bx,ax                       ;BX=代表光标位置的16位数

		;是否是回车符
         cmp cl,0x0d                     ;回车符？如果不是回车符就跳转到75行执行，如果是回车符就接着执行68行
         jnz .put_0a                     ;不是。看看是不是换行等字符 
         mov ax,bx                       ;此句略显多余，但去掉后还得改书，麻烦 
         mov bl,80                       
         div bl							;ax除以80
         mul bl							;ax乘以80
         mov bx,ax						;如果是回车符，就把光标移动到当前行的开始处
         jmp .set_cursor

 .put_0a:  ;是否是换行符		
         8cmp cl,0x0a                     ;换行符？  如果不是换行符，就转到81行执行，如果是换行符，就继续执行78行
         jnz .put_other                  ;不是，那就正常显示字符 
         add bx,80
         jmp .roll_screen

 .put_other:                             ;正常显示字符
         mov ax,0xb800
         mov es,ax
         shl bx,1						;将bx左移1位(即bx = bx*2)
         mov [es:bx],cl

         ;以下将光标位置推进一个字符
         shr bx,1						;将bx右移1位(即bx = bx/2)
         add bx,1

 .roll_screen:
         cmp bx,2000                     ;光标超出屏幕？滚屏
         jl .set_cursor					;如果bx<2000，则跳转执行112行
		
		push bx							;如果bx>=2000,则继续执行95行
         mov ax,0xb800					
         mov ds,ax
         mov es,ax
         cld
         mov si,0xa0
         mov di,0x00
         mov cx,1920
         rep movsw
		 
         mov bx,3840                     ;清除屏幕最底一行
         mov cx,80						;在屏幕最后一行写入80个空格
 .cls:
         mov word[es:bx],0x0720			;07是黑底白字，20是空格字符的16进制编码
         add bx,2
         loop .cls

         ;mov bx,1920
		pop bx
		sub bx, 80
 .set_cursor:							;写入光标位置(存放在bx)：向寄存器0x0e写入光标数值bx的高8位，向寄存器0x0f写入光标数值bx的低8位
         mov dx,0x3d4
         mov al,0x0e
         out dx,al						;通过索引端口0x3d4，通知显卡现在要操作0x0e号寄存器
         mov dx,0x3d5
         mov al,bh
         out dx,al						;通过索引端口0x3d5，向寄存器0x0e写入光标数值bx的高8位，向端口写入，只能使用al
         mov dx,0x3d4
         mov al,0x0f					
         out dx,al						;通过索引端口0x3d4，通知显卡现在要操作0x0f号寄存器
         mov dx,0x3d5
         mov al,bl
         out dx,al						;通过索引端口0x3d5，向寄存器0x0f写入光标数值bx的低8位，向端口写入，只能使用al

         pop es
         pop ds
         pop dx
         pop cx
         pop bx
         pop ax

         ret

;-------------------------------------------------------------------------------
  start:
         ;初始执行时，DS和ES指向用户程序头部段
         mov ax,[stack_segment]           ;设置到用户程序自己的堆栈 
         mov ss,ax
         mov sp,stack_end
         
         mov ax,[data_1_segment]          ;设置到用户程序自己的数据段
         mov ds,ax

         mov bx,msg0
         call put_string                  ;显示第一段信息 

         push word [es:code_2_segment]
         mov ax,begin
         push ax                          ;可以直接push begin,80386+
         
         retf                             ;转移到代码段2执行 
         
  continue:
         mov ax,[es:data_2_segment]       ;段寄存器DS切换到数据段2 
         mov ds,ax
         
         mov bx,msg1
         call put_string                  ;显示第二段信息 

         jmp $ 

;===============================================================================
SECTION code_2 align=16 vstart=0          ;定义代码段2（16字节对齐）

  begin:
         push word [es:code_1_segment]
         mov ax,continue
         push ax                          ;可以直接push continue,80386+
         
         retf                             ;转移到代码段1接着执行 
         
;===============================================================================
SECTION data_1 align=16 vstart=0

    msg0 db '  This is NASM - the famous Netwide Assembler. '
         db 'Back at SourceForge and in intensive development! '
         db 'Get the current versions from http://www.nasm.us/.'
         db 0x0d,0x0a,0x0d,0x0a
         db '  Example code for calculate 1+2+...+1000:',0x0d,0x0a,0x0d,0x0a
         db '     xor dx,dx',0x0d,0x0a
         db '     xor ax,ax',0x0d,0x0a
         db '     xor cx,cx',0x0d,0x0a
         db '  @@:',0x0d,0x0a
         db '     inc cx',0x0d,0x0a
         db '     add ax,cx',0x0d,0x0a
         db '     adc dx,0',0x0d,0x0a
         db '     inc cx',0x0d,0x0a
         db '     cmp cx,1000',0x0d,0x0a
         db '     jle @@',0x0d,0x0a
         db '     ... ...(Some other codes)',0x0d,0x0a,0x0d,0x0a
         db 0

;===============================================================================
SECTION data_2 align=16 vstart=0

    msg1 db '  The above contents is written by LeeChung. '
         db '2011-05-06'
         db 0

;===============================================================================
SECTION stack align=16 vstart=0
           
         resb 256

stack_end:  

;===============================================================================
SECTION trail align=16
program_end:
