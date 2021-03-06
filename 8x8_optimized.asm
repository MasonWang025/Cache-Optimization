##################################
# After playing around, here is the best hit rate:
# (only with direct mapped and 2-way associative)
###
# Cache parameters: 
# Cache size of 256 bytes
# 16 blocks of 4 words each (64 words total) 
###
# Direct mapped -----> 78% hit rate
# 2-way associative -> 84% hit rate
# 6% increase in hit rate, 84% is the highest achievable with 2-way and direct-mapped caches of size 256 bytes
# Hit rate often increases as associativity increases with this blocked version (unlike the unoptimized)
# This probably says less about caches in general than it does the MIPS cache simulator
# But this is a worthy observation nonetheless
###
# The same configuration above jumps to 93% hit rate for 4-way associativity
# Many configurations are able to reach about 93% for 4 way or full associativity
# Overall, the hit rate is much higher than the non-blocked version was able to achieve
##################################
.text
start:
	# matrix multiply
	la $a2, M2
	la $a1, M1
	la $a0, product
	# M1 * M2 -> product
	jal matrix_multiply
	
	# print output
	la $a0, product
	jal print_matrix
	
	# exit
	li $v0, 10
	syscall

# a1 * a2 -> a0
# 8x8 matrices
matrix_multiply:
	# written to reflect book's C code as closely as possible
	move $s0, $a0 # product
	move $s1, $a1 # M1
	move $s2, $a2 # M2
	
	li $s3, 0 # si = 0; initialize 1st for loop
	L1: li $s4, 0 # sj = 0; restart 2nd for loop
		L2: li $s5, 0 # sk = 0; restart 3rd for loop
			L3: # inner loop, do_block
				# save registers and jump to do_block
				addi $sp, $sp, -28
				sw $ra, 24($sp) # return address
				sw $s0, 20($sp) # product address
				sw $s1, 16($sp) # M1 address
				sw $s2, 12($sp) # M2 address
				sw $s3, 8($sp) # si
				sw $s4, 4($sp) # sj
				sw $s5, 0($sp) # sk
				
				# do_block(si, sj, sk, A, B, C);
				# where A is M1, B is M2, and C is product
				move $a0, $s3 # si
				move $a1, $s4 # sj
				move $a2, $s5 # sk
				
				# A, B, C will be in registers s0, s1, s2
				jal do_block
				
				# restore registers
				lw $s5, 0($sp) # sk
				lw $s4, 4($sp) # sj
				lw $s3, 8($sp) # si
				lw $s2, 12($sp) # M2 address
				lw $s1, 16($sp) # M1 address
				lw $s0, 20($sp) # product address
				lw $ra, 24($sp) # return address
				addi $sp, $sp, 28
				
				addi $s5, $s5, 4 # sk += BLOCKSIZE
				bne $s5, 8, L3 # if (sk != 8) go to L3
				addi $s4, $s4, 4 # sj += BLOCKSIZE
				bne $s4, 8, L2 # if (sj != 8) go to L2
				addi $s3, $s3, 4 # si += BLOCKSIZE
				bne $s3, 8, L1 # if (si != 8) go to L1
	jr $ra

do_block:
	# values for conditional statements in loops to test against
	# calculate only once prior to loops to save time and register usage
	# si, sj, and sk in $a0, $a1, $a2 respectively
	addi $t0, $a0, 4 # i < si + BLOCKSIZE, so stop value is (si + BLOCKSIZE) = ($a0 + 4) => $t0
	addi $t1, $a1, 4 # j < sj + BLOCKSIZE, so stop value is (sj + BLOCKSIZE) = ($a1 + 4) => $t1
	addi $t2, $a2, 4 # k < sk + BLOCKSIZE, so stop value is (sk + BLOCKSIZE) = ($a2 + 4) => $t2
	
	# i, j, k will be in $s3, $s4, $s5 respectively
	move $s3, $a0 # i = si
	blockL1: 
		move $s4, $a1 # j = sj, restart second loop
		blockL2:
			move $s5, $a2 # k = sk, restart third loop
			# get address of "product[i][j]", or more accurately, product[(i*8)+j]
			# first, set t3 to offset value of (i*8) + j
			sll $t3, $s3, 3 # i*8
			add $t3, $t3, $s4 # (i*8) + j
			sll $t3, $t3, 2 # byte offset
			add $t3, $t3, $s0 # add offset with base address
			# t3 now contains "product[i][j]" address
			lw $t7, 0($t3) # the cumulative sum to be written back into "product[i][j]"
			blockL3:	
				# M1[(i * 8) + k] 
				li $t4, 0
				sll $t4, $s3, 3 # i*8
				addu $t4, $t4, $s5 # (i*8) + k
				sll $t9, $t4, 2 # byte offset of [i][k]
				addu $t4, $t9, $s1 # add offset with base address
				lw $t4, 0($t4)
				# t4 now contains value of "M1[i][k]"
				# M2[(k * 8) + j]
				li $t5, 0
				sll $t5, $s5, 3 # k*8
				addu $t5, $t5, $s4 # (k*8) + j
				sll $t8, $t5, 2 # byte offset of [k][j]
				addu $t5, $t8, $s2 # add offset with base address
				lw $t5, 0($t5)
				# t5 now contains value of "M2[i][k]"
				
				mul $t5, $t4, $t5 # M1[(i * 8) + k] \* M2[(k * 8) + j]
				add $t7, $t7, $t5 # cij += (product of t4 and t5)
				# t7 is cumulative sum of products for blockL3 loop
				
				# increment counter then test against the pre-calculated stop values
				addi $s5, $s5, 1 # ++k
				bne $s5, $t2, blockL3 # (if k != (sk + BLOCKSIZE)) go to L3
				
				# write t7 (cumulative sum) back into product[i][j]
				sw $t7, 0($t3)
				
				addi $s4, $s4, 1 # ++j
				bne $s4, $t1, blockL2 # (if j != (sj + BLOCKSIZE)) go to L2
				addi $s3, $s3, 1 # ++i
				bne $s3, $t0, blockL1 # (if i != (si + BLOCKSIZE)) go to L1
	jr $ra

# prints 8x8 matrix at $a0
print_matrix:
	li $s0, 0 # index
	move $s1, $a0 # matrix to print
	matrix_print_loop:
		# get address $t2 (address with vector to print)
		sll $s2, $s0, 5 # 32 bit offset per print
		add $s3, $s1, $s2 # add offset $t2 to $t1, store in $t3
		
		move $a0, $s0
		# save return address
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		jal print_row_prompt
	
		move $a0, $s3 # address of vector to print
		li $a1, 8 # number of integers to print
		jal print_vector
		
		# restore return address
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		
		# print new line
		li $v0, 4
		la $a0, new_line
		syscall
		
		addi $s0, $s0, 1 # index++
		bne $s0, 8, matrix_print_loop # loop until 4 vector reads finish
	
	jr $ra

# procedure to print the vector at $a0, length of vector is $a1
print_vector:
	li $t0, 0 # index
	move $t1, $a0 # array's address
	
	vector_print_loop:
		# get address $t1 with index offset
		sll $t2, $t0, 2 # offset bytes in $t2
		add $t3, $t1, $t2 # add offset $t2 to $t1, store in $t3
		
		# print current int
		li $v0, 1
		lw $a0, 0($t3)
		syscall
		
		# print space
		li $v0, 4
		la $a0, space
		syscall
		
		addi $t0, $t0, 1 # index++
		bne $t0, $a1, vector_print_loop # loop if index has not reached bound
	jr $ra

# print 'Row [i]: ' where i is $a0, the index
print_row_prompt:
	addi $t9, $a0, 1 # row number
	li $v0, 4
	la $a0, row
	syscall
	
	li $v0, 1
	move $a0, $t9
	syscall
	
	li $v0, 4
	la $a0, colon
	syscall
	
	jr $ra

.data
# two defined 8 by 8 matrices
M1: .word 1, 2, 1, 1, 0, 0, 1, 2,
		  0, 4, 0, 1, 7, 4, 3, 3,
		  2, 3, 4, 1, 6, 1, 9, 1,
		  1, 9, 7, 0, 7, 8, 1, 2,
		  2, 1, 8, 6, 8, 2, 1, 1,
		  6, 1, 8, 1, 0, 2, 1, 7,
		  1, 2, 9, 1, 2, 7, 1, 9,
		  6, 1, 1, 1, 6, 2, 2, 1
		  
M2: .word 8, 8, 9, 1, 7, 1, 2, 3,
		  1, 3, 0, 0, 1, 2, 4, 5,
		  5, 2, 5, 7, 2, 8, 5, 7,
		  3, 3, 0, 5, 2, 0, 0, 0,
		  2, 0, 0, 5, 9, 7, 8, 8,
		  1, 9, 7, 8, 3, 3, 0, 1,
		  2, 3, 5, 1, 6, 6, 2, 3,
		  7, 0, 1, 1, 2, 4, 6, 4						

product: .space 256 # M1 x M2 = product (dot product) 
row: .asciiz "Row "
colon: .asciiz ": "
new_line: .asciiz "\n"
space: .asciiz " "
