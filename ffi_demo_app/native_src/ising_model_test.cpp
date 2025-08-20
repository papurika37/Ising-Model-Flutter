#include<iostream>
#include<time.h>
#include<stdlib.h>
#include<math.h>
using namespace std;
int main(){
    srand((unsigned int) time(NULL));
    int N;
    cout<<"model size";
    cin>>N;
    cout<<N<<endl;
    float J;
    cout<<"interaction";
    cin>>J;
    cout<<J<<endl;
    double temp;
    cout<<"Temperture";
    cin>>temp;
    cout<<temp<<endl;
    int magnetic=0;
    unsigned long T=0;
    float E=0;
    int model[N][N];
    float energy[N][N];
    float p=0;
    for(int k=0;k<N;k++){
        for(int l=0;l<N;l++){
            model[k][l]=1;
        }
    }
    while(1){
        for(int k=0;k<N;k++){
            for(int l=0;l<N;l++){
                p = exp(2*energy[k][l]/temp);
                if(rand()<p){
                    model[k][l]*=-1;
                }
            }
        }
        E=0;
        magnetic=0;
        for(int k=0;k<N;k++){
            for(int l=0;l<N;l++){
                energy[k][l] = -J*(model[(k+1)%N][l]+model[k][(l+1)%N])*model[k][l];
                E += energy[k][l];
                magnetic += model[k][l];
                cout<<(model[k][l]+1)/2;;
            }
            cout<<endl;
        }
        cout<<"Time: "<<T<<endl;
        cout<<"Energy: "<<E<<endl;
        cout<<"Magnetic: "<<(float)abs(magnetic)/(N*N)<<endl;

        T++;
    }
}