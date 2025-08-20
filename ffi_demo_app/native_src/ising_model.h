// native_src/ising_model.h

#ifndef ISING_MODEL_H
#define ISING_MODEL_H

#include <vector>
#include <random>
#include <string>
#include <map>

#if defined(_WIN32) || defined(_WIN64)
    #define FFI_API __declspec(dllexport)
#else
    #define FFI_API __attribute__((visibility("default")))
#endif

class IsingModel {
public:
    IsingModel(int n_size, float j_interaction, double temperature);
    ~IsingModel();

    void step();
    void getState(int* out_state_array) const;
    int getSize() const;
    double getEnergy() const;
    double getMagneticMoment() const;
    unsigned long getTimeStep() const;
    const char* getLastError() const;

    void setTemperature(double new_temperature); // ★温度を設定するメソッドを追加

private:
    void initialize_spins();
    void calculate_total_energy_and_magnetization();
    void initialize_exp_lookup_table();

    int N;
    float J;
    double temp; // この値を動的に変更する
    std::vector<std::vector<int>> model;

    double current_total_energy;
    int current_total_magnetic_moment_sum;
    unsigned long current_time_step;
    std::string last_error_message_;

    std::mt19937 rng;
    std::uniform_real_distribution<double> unif_dist_01;
    
    std::map<int, double> exp_lookup_table_;
};

extern "C" {
    typedef IsingModel* IsingModelPtr;

    FFI_API IsingModelPtr create_ising_model(int n_size, float j_interaction, double temperature);
    FFI_API void delete_ising_model(IsingModelPtr model_ptr);
    FFI_API void run_sweeps_ising_model(IsingModelPtr model_ptr, int num_sweeps);
    FFI_API void set_ising_model_temperature(IsingModelPtr model_ptr, double new_temperature); // ★FFI関数宣言を追加
    FFI_API void get_ising_model_state(IsingModelPtr model_ptr, int* out_state_array);
    FFI_API int get_ising_model_size(IsingModelPtr model_ptr);
    FFI_API double get_ising_model_energy(IsingModelPtr model_ptr);
    FFI_API double get_ising_model_magnetic_moment(IsingModelPtr model_ptr);
    FFI_API unsigned long get_ising_model_time(IsingModelPtr model_ptr);
    FFI_API const char* get_last_error(IsingModelPtr model_ptr);
}

#endif // ISING_MODEL_H