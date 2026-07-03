
int main() {
    GET_PARAMETERS();
    
    if (__argc > 1) {
        printf("%s\n", __argv[1]);
    }


    return 0;
}