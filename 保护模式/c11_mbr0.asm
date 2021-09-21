         ;代码清单11-1
         ;文件名：c11_mbr0.asm
         ;文件说明：硬盘主引导扇区代码
         ;创建日期：2020-6-7 15:00

         ;计算GDT所在的逻辑段地址
         mov ax,[cs:gdt_base+0x7c00]        ;低16位 
         mov dx,[cs:gdt_base+0x7c00+0x02]   ;高16位 
         mov bx,16        					
         div bx            					;这里把dx和ax组成的地址除以16就得到了段地址（存储在ax中）和偏移地址（存储在dx中）
         mov ds,ax                          ;令DS指向该段以进行操作
         mov bx,dx                          ;段内起始偏移地址 
      
         ;创建0#描述符，它是空描述符，这是处理器的要求
         mov dword [bx+0x00],0x00           ;dword是4个字节
         mov dword [bx+0x04],0x00  

         ;创建#1描述符，保护模式下的数据段描述符（文本模式下的显示缓冲区）
         mov dword [bx+0x08],0x8000ffff
         mov dword [bx+0x0c],0x0040920b

         ;初始化描述符表寄存器GDTR
         mov word [cs: gdt_size+0x7c00],15  ;描述符表的界限（总字节数减一）
                                             
         lgdt [cs: gdt_size+0x7c00]			;lgdt指令从内存中取6个字节的数据到GDTR；lgdt指令在实模式和保护模式下都可以执行
      
         in al,0x92                         ;南桥芯片内的端口   使用in指令从A92端口读出1个字节数据
         or al,0000_0010B
         out 0x92,al                        ;打开A20

         cli                                ;保护模式下中断机制尚未建立，应 
                                            ;禁止中断 		保护模式下的中断机制和实模式不相同，原有的中单向量表不再适用；
											;在保护模式下需要重新建立一套新的中断处理机制，但是我们现在没有做这种工作，所以
											;如果当前发生中断，肯定会发生问题，因此需要关闭中断，，另外，在保护模式下，bios
											;中断也不能再使用，因为bios是使用逻辑地址*16+偏移地址的方式寻址的
         mov eax,cr0					;将cr0寄存器中的原有内容传递给eax寄存器
         or eax,1
         mov cr0,eax                        ;设置PE位

         ;以下进入保护模式... ...

         mov cx,00000000000_01_000B         ;加载数据段选择子(0x01)
         mov ds,cx

         ;以下在屏幕上显示"Protect mode OK."
         mov byte [0x00],'P'
         mov byte [0x02],'r'
         mov byte [0x04],'o'
         mov byte [0x06],'t'
         mov byte [0x08],'e'
         mov byte [0x0a],'c'
         mov byte [0x0c],'t'
         mov byte [0x0e],' '
         mov byte [0x10],'m'
         mov byte [0x12],'o'
         mov byte [0x14],'d'
         mov byte [0x16],'e'
         mov byte [0x18],' '
         mov byte [0x1a],'O'
         mov byte [0x1c],'K'

         hlt                                ;已经禁止中断，将不会被唤醒 

;-------------------------------------------------------------------------------
     
         gdt_size         dw 0									;dw是2个字节
         gdt_base         dd 0x00007e00     ;GDT的物理地址		dd是4个字节
                             
         times 510-($-$$) db 0
                          db 0x55,0xaa
