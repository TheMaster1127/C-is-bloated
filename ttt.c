
void print_board(int *arr) {
 printf("-------------\n");
 printf("| %c | %c | %c |\n", arr[1], arr[2], arr[3]);
 printf("-------------\n");
 printf("| %c | %c | %c |\n", arr[4], arr[5], arr[6]);
  printf("-------------\n");
 printf("| %c | %c | %c |\n", arr[7], arr[8], arr[9]);
     printf("-------------\n");
    
}

int is_draw(int *arr) {

     if (arr[1] != ' ' && arr[2] != ' ' && arr[3] != ' ' && arr[4] != ' ' && arr[5] != ' ' && arr[6] != ' ' && arr[7] != ' ' && arr[8] != ' ' && arr[9] != ' ') {
      return 1;
     }
     else {
      return 0;
     }
return 0;
}

int is_a_win(int *arr) {

     if (arr[1] == 'X' && arr[2] == 'X' && arr[3] == 'X') {
      return 1;
     }
     else if (arr[4] == 'X' && arr[5] == 'X' && arr[6] == 'X') {
      return 1;
     }
    else if (arr[7] == 'X' && arr[8] == 'X' && arr[9] == 'X') {
      return 1;
     }
    else if (arr[1] == 'X' && arr[4] == 'X' && arr[7] == 'X') {
      return 1;
     }
    else if (arr[2] == 'X' && arr[5] == 'X' && arr[8] == 'X') {
      return 1;
     }
    else if (arr[3] == 'X' && arr[6] == 'X' && arr[9] == 'X') {
      return 1;
     }
    else if (arr[1] == 'X' && arr[5] == 'X' && arr[9] == 'X') {
      return 1;
     }
    else if (arr[3] == 'X' && arr[5] == 'X' && arr[7] == 'X') {
      return 1;
    }
    else if (arr[1] == 'O' && arr[2] == 'O' && arr[3] == 'O') {
      return 2;
     }
     else if (arr[4] == 'O' && arr[5] == 'O' && arr[6] == 'O') {
      return 2;
     }
    else if (arr[7] == 'O' && arr[8] == 'O' && arr[9] == 'O') {
      return 2;
     }
    else if (arr[1] == 'O' && arr[4] == 'O' && arr[7] == 'O') {
      return 2;
     }
    else if (arr[2] == 'O' && arr[5] == 'O' && arr[8] == 'O') {
      return 2;
     }
    else if (arr[3] == 'O' && arr[6] == 'O' && arr[9] == 'O') {
      return 2;
     }
    else if (arr[1] == 'O' && arr[5] == 'O' && arr[9] == 'O') {
      return 2;
     }
    else if (arr[3] == 'O' && arr[5] == 'O' && arr[7] == 'O') {
      return 2;
    }
    else {
     return 0;
    }

return 0;
}

int main() {
    
    int win = 0;
    
    int game_arr[10];
    
    game_arr[1] = ' ';
    game_arr[2] = ' ';
    game_arr[3] = ' ';
    game_arr[4] = ' ';
    game_arr[5] = ' ';
    game_arr[6] = ' ';
    game_arr[7] = ' ';
    game_arr[8] = ' ';
    game_arr[9] = ' ';
    
    char in = ' ';
    int gameState = 0;
    
    int player = 1;
    print_board(game_arr);
    while (gameState != 99) {
    gameState = 0;
    while (gameState != 1) {
        if (player == 1) {
         printf("hey player 1 type a num: ");
        }
        else {
         printf("hey player 2 type a num: ");
        }
        
        scanf(" %c", &in);
        
        // 49 = 1 ... 57 = 9
        if (in >= 49 && in <= 57) {
            gameState = 1;
        }
        else {
            printf("ERROR YOU ENTERED THE WRONG THING ONLY 123456789\n\n");
        }
    }


    if (game_arr[in - 48] == ' ') {
     
     if (player == 1) {
     player = 2;
     game_arr[in - 48] = 'X';
     }
     else {
     game_arr[in - 48] = 'O';
     player = 1;
     }
     

    }
    else {
     printf("The spot is already taken.\n");
    }
 
 print_board(game_arr);
 
 
 if (win != 99) {
  
  if (is_a_win(game_arr) == 1) {
  win = 0;
  gameState = 99;
  }
  else if (is_a_win(game_arr) == 2) {
  win = 1;
  gameState = 99;
  }

if (gameState != 99) {
 if (is_draw(game_arr) == 1) {
  win = 99;
  gameState = 99;
 }
}

  
 }
 
    
}
 
 if (win == 0) {
    printf("player 1 wins!!!\n");
 }
 else {
     
     if (win == 99) {
    printf("DRAW NO ONE WINS!!!\n");
     }
     else {
     
    printf("player 2 wins!!!\n");
     }
 }
    return 0;
}