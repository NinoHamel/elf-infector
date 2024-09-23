; section pour les constantes
section .data
    filename db 'binary', 0  ; Nom du fichier
    not_elf db 'The binary is not an ELF file', 0xA
    not_elf_len equ $ - not_elf
    is_elf db 'The binary is an ELF', 0xA
    is_elf_len equ $ - is_elf
    error_msg db 'Error opening file', 0xA  ; Message d'erreur (avec nouvelle ligne)
    error_len equ $ - error_msg   ; Longueur du message d'erreur

; section pour les variables
section .bss
    buffer resb 4                ; Réserve un buffer de 64 octets pour lire l'entête

; section pour le code
section .text
    global _start

; Main
_start:

    call open_file
    call read_file
    ; call print_buffer
    call cmp_header
    call close_file
    jmp exit_program 

; Ouvrir le fichier
open_file:
    mov rax, 2                    ; numéro de syscall pour open
    mov rdi, filename             ; pointeur vers le nom du fichier
    mov rsi, 0                    ; flags : mode lecture seule
    xor rdx, rdx                  ; mode : non utilisé pour la lecture seule
    syscall                      

    ; Vérifie si le fichier a été ouvert avec succès
    cmp rax, 0
    jl open_error                 ; Si la valeur de retour < 0, c'est une erreur
    mov rdi, rax                  ; Sauvegarde le descripteur de fichier dans rdi
    ret                            

; Lire les premiers octets du fichier
read_file:
    ; rdi = fd (filename)
    mov rax, 0                    ; syscall pour lire
    mov rsi, buffer               ; buffer pour stocker les octets
    mov rdx, 4                ; nombre d'octets à lire
    syscall                       
    ret

; Regarder si le fichier est un elf (4 premiers bytes = .ELF)
cmp_header:
    mov rax, [buffer]
    cmp rax,  0x464c457f ;.ELF en hexa (little endian)
    je print_success_equal ; si égal

    ;sinon
    jne print_not_equal

print_success_equal:
    mov rax, 1 ; syscall pour écrire
    mov rdi, 1 ; descripteur de fichier : stdout
    mov rsi, is_elf; rsi = buffer (la valeur à écrire)
    mov rdx, is_elf_len ; (la taille du buffer)
    syscall
    ret

print_not_equal:
    mov rax, 1 ; syscall pour écrire
    mov rdi, 1 ; descripteur de fichier : stdout
    mov rsi, not_elf; rsi = buffer (la valeur à écrire)
    mov rdx, not_elf_len ;(la taille du buffer)
    syscall
    jmp exit_program

; Afficher le buffer
print_buffer:
    mov rax, 1 ; syscall pour écrire
    mov rdi, 1 ; descripteur de fichier : stdout
    mov rsi, buffer ; rsi = buffer (la valeur à écrire)
    mov rdx, 4; rdx = 4 (la taille du buffer)
    syscall
    ret

; Fermer le fichier
close_file:
    mov rax, 3 ; syscall pour fermer
    syscall
    ret

; Afficher le message d'erreur si on a pas pu ouvrir le fichier
open_error:
    mov rax, 1                    ; syscall pour écrire
    mov rdi, 1                    ; descripteur de fichier : stdout
    mov rsi, error_msg            ; pointeur vers le message d'erreur
    mov rdx, error_len            ; longueur du message d'erreur
    syscall                

; Terminer le programme
exit_program:
    mov rax, 60                   ; syscall pour exit
    xor rdi, rdi                  ; statut : 0
    syscall
    
