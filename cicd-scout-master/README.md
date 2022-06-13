# Aktualní pipeline

### master
1. build
2. testy
3. deploy master
4. tag (aktualne dummy step, ale mohl by checkovat CL a delat automaticky tagy) (manualni)
5. deploy testing (manualni)
6. deploy staging (manualni)
7. deploy stable (manualni)
  
### branch
1. build
2. branch
   1. deploy master (manualni)
   2. stop deplyment (manualni/auto po 1dni)

### merge request
1. build
2. testy
3. branch
   1. deploy master (manualni)
   2. stop deplyment (manualni/auto po 1dni)

