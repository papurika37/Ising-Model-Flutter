// native_src/ising_model.cpp

#include "ising_model.h"
#include <cmath>
#include <stdexcept>
#include <iostream> // デバッグ用 (最終的には削除推奨)

// ... (IsingModelのコンストラクタ、デストラクタ、他のメソッド実装は前回の回答と同じ) ...
// (initialize_spins, calculate_total_energy_and_magnetization, initialize_exp_lookup_table, step, getState など)
IsingModel::IsingModel(int n_size, float j_interaction, double temperature)
    : N(n_size), J(j_interaction), temp(temperature), current_time_step(0),
      rng(std::random_device{}()), unif_dist_01(0.0, 1.0) {
    if (N <= 0) {
        last_error_message_ = "Model size N must be positive.";
        throw std::runtime_error(last_error_message_);
    }
    if (this->temp < 0) { // temp はメンバ変数を指す
        last_error_message_ = "Temperature must be non-negative.";
         // 0Kでのシミュレーションはフリップ確率の扱いが変わるので注意
        if (this->temp == 0) this->temp = 1e-9; // exp のために非常に小さい正の値に
        // throw std::runtime_error(last_error_message_);
    }
    
    model.resize(N, std::vector<int>(N));
    initialize_spins();
    initialize_exp_lookup_table();
}

IsingModel::~IsingModel() {}

void IsingModel::initialize_spins() { /* ...前回答と同じ... */ 
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            model[i][j] = 1; 
        }
    }
    calculate_total_energy_and_magnetization();
}

void IsingModel::calculate_total_energy_and_magnetization() { /* ...前回答と同じ... */ 
    current_total_energy = 0;
    current_total_magnetic_moment_sum = 0;
    for (int k = 0; k < N; ++k) {
        for (int l = 0; l < N; ++l) {
            current_total_energy += -J * static_cast<double>(model[k][l])
                                  * (model[(k + 1) % N][l] + model[k][(l + 1) % N]);
            current_total_magnetic_moment_sum += model[k][l];
        }
    }
}

void IsingModel::initialize_exp_lookup_table() { /* ...前回答と同じ... */ 
    exp_lookup_table_.clear();
    if (this->temp <= 1e-9) { // this->temp を使用
        // std::cout << "Temperature is near zero, lookup table not populated extensively." << std::endl;
        return; 
    }
    exp_lookup_table_[2] = std::exp(-(4.0 * J) / this->temp);
    exp_lookup_table_[4] = std::exp(-(8.0 * J) / this->temp);
    // std::cout << "Lookup Table RE-INITIALIZED for T=" << this->temp << ", J=" << J << std::endl;
    // for(const auto& pair : exp_lookup_table_) {
    //     std::cout << "delta_E_div_2J: " << pair.first << ", exp_val: " << pair.second << std::endl;
    // }
}

// ★新しいメソッド: 温度を設定し、ルックアップテーブルを再初期化
void IsingModel::setTemperature(double new_temperature) {
    last_error_message_.clear(); // 古いエラーメッセージをクリア
    if (new_temperature < 0) {
        last_error_message_ = "New temperature must be non-negative.";
        // ここでエラーをどう扱うか: 例外を投げるか、エラーメッセージを設定して処理を続行しないか
        // 簡単のため、エラーメッセージを設定し、温度は変更しない
        std::cerr << "Error: " << last_error_message_ << std::endl;
        return;
    }
    
    this->temp = (new_temperature == 0) ? 1e-9 : new_temperature; // 0Kの場合は微小な正の値に
    
    // std::cout << "Temperature changed to: " << this->temp << std::endl;
    initialize_exp_lookup_table(); // 新しい温度でルックアップテーブルを更新
}


void IsingModel::step() { /* ...前回答と同じ (this->temp を使用) ... */ 
    if (N == 0) return;
    for (int i_trial = 0; i_trial < N * N; ++i_trial) {
        int k = static_cast<int>(unif_dist_01(rng) * N); 
        if (k == N) k = N - 1; 
        int l = static_cast<int>(unif_dist_01(rng) * N);
        if (l == N) l = N - 1; 

        double sum_neighbor_spins = static_cast<double>(
            model[(k + 1) % N][l] + model[(k - 1 + N) % N][l] +
            model[k][(l + 1) % N] + model[k][(l - 1 + N) % N]);
        double delta_E = 2.0 * J * model[k][l] * sum_neighbor_spins;

        bool accept_flip = false;
        if (delta_E <= 0) {
            accept_flip = true;
        } else if (this->temp > 1e-9) { // this->temp を使用
            int lookup_key = static_cast<int>(round(delta_E / (2.0 * J)));
            auto it = exp_lookup_table_.find(lookup_key);
            if (it != exp_lookup_table_.end()) {
                if (unif_dist_01(rng) < it->second) {
                    accept_flip = true;
                }
            } else { 
                 if (unif_dist_01(rng) < std::exp(-delta_E / this->temp)) { // this->temp を使用
                     accept_flip = true;
                 }
            }
        }
        if (accept_flip) {
            model[k][l] *= -1;
        }
    }
    calculate_total_energy_and_magnetization(); 
    current_time_step++;
}

// getState, getSize, getEnergy, getMagneticMoment, getTimeStep, getLastError の実装は変更なし
void IsingModel::getState(int* out_state_array) const { /* ...前回答と同じ... */ 
    if (!out_state_array || N == 0) return;
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            out_state_array[i * N + j] = (model[i][j] + 1) / 2;
        }
    }
}
int IsingModel::getSize() const { return N; }
double IsingModel::getEnergy() const { return current_total_energy; }
double IsingModel::getMagneticMoment() const {
    if (N == 0) return 0.0;
    return static_cast<double>(std::abs(current_total_magnetic_moment_sum)) / (N * N);
}
unsigned long IsingModel::getTimeStep() const { return current_time_step; }
const char* IsingModel::getLastError() const {
    return last_error_message_.empty() ? nullptr : last_error_message_.c_str();
}

// --- FFI Cラッパー関数の実装 ---
FFI_API IsingModelPtr create_ising_model(int n_size, float j_interaction, double temperature) { /* ...前回答と同じ... */ 
    try { return new IsingModel(n_size, j_interaction, temperature); } catch (...) { return nullptr; }
}
FFI_API void delete_ising_model(IsingModelPtr model_ptr) { /* ...前回答と同じ... */ 
    delete model_ptr;
}
FFI_API void run_sweeps_ising_model(IsingModelPtr model_ptr, int num_sweeps) { /* ...前回答と同じ... */ 
    if (model_ptr && num_sweeps > 0) { for (int i = 0; i < num_sweeps; ++i) model_ptr->step(); }
}

// ★新しいFFIラッパー関数: 温度を設定
FFI_API void set_ising_model_temperature(IsingModelPtr model_ptr, double new_temperature) {
    if (model_ptr) {
        model_ptr->setTemperature(new_temperature);
    }
}

FFI_API void get_ising_model_state(IsingModelPtr model_ptr, int* out_state_array) { /* ...前回答と同じ... */ 
    if (model_ptr && out_state_array) model_ptr->getState(out_state_array);
}
FFI_API int get_ising_model_size(IsingModelPtr model_ptr) { /* ...前回答と同じ... */ 
    return model_ptr ? model_ptr->getSize() : 0;
}
FFI_API double get_ising_model_energy(IsingModelPtr model_ptr) { /* ...前回答と同じ... */ 
    return model_ptr ? model_ptr->getEnergy() : 0.0;
}
FFI_API double get_ising_model_magnetic_moment(IsingModelPtr model_ptr) { /* ...前回答と同じ... */ 
    return model_ptr ? model_ptr->getMagneticMoment() : 0.0;
}
FFI_API unsigned long get_ising_model_time(IsingModelPtr model_ptr) { /* ...前回答と同じ... */ 
    return model_ptr ? model_ptr->getTimeStep() : 0;
}
FFI_API const char* get_last_error(IsingModelPtr model_ptr) { /* ...前回答と同じ... */ 
    return (model_ptr && model_ptr->getLastError()) ? model_ptr->getLastError() : "No error or model not initialized.";
}