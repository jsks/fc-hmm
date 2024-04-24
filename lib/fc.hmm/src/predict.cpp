#include <Eigen/Dense>
#include <vector>
#include <iostream>

#include <cpp11.hpp>

using namespace Eigen;
using namespace cpp11;

VectorXd rowwise_softmax(const MatrixXd& m) {
  MatrixXd result = (m.colwise() - m.rowwise().maxCoeff()).array().exp();
  for (auto i = 0; i < result.rows(); i++) {
    result.row(i) /= result.row(i).sum();
  }

  return result.colwise().mean();
}

void eigen_predict(MatrixXd& effects,
                    const MatrixXd& beta,
                    const MatrixXd& zeta,
                    const MatrixXd& X,
                    const std::vector<double>& v) {
  // N x K + N x D * D x K -> N x K
  MatrixXd base = zeta + X * beta.rightCols(beta.cols() - 1).transpose();
  MatrixXd base_adjusted(base.rows(), base.cols());

  for (auto i = 0; i < v.size(); i++) {
    base_adjusted = base.rowwise() + (beta.col(0) * v[i]).transpose();
    effects.col(i) = rowwise_softmax(base_adjusted);
  }
}

writable::doubles_matrix<> as_matrix(const MatrixXd& m) {
  writable::doubles_matrix<> out(m.rows(), m.cols());
  std::copy(m.data(), m.data() + m.size(), REAL(out.data()));

  return out;
}

[[cpp11::register]]
list posterior_predict(const list_of<doubles_matrix<>>& beta,
                       const list_of<doubles_matrix<>>& zeta,
                       const doubles_matrix<>& X,
                       const doubles& tiv,
                       int cores) {
  if (beta.size() != zeta.size())
    stop("beta and zeta must have the same length");

  if (beta.size() == 0)
    stop("length of beta and zeta must be >0");

  std::vector<MatrixXd> beta_eigen(beta.size()), zeta_eigen(zeta.size());
  for (auto i = 0; i < beta.size(); i++) {
    beta_eigen[i] = Map<MatrixXd>(REAL(beta[i].data()), beta[i].nrow(), beta[i].ncol());
    zeta_eigen[i] = Map<MatrixXd>(REAL(zeta[i].data()), zeta[i].nrow(), zeta[i].ncol());
  }

  Map<MatrixXd> X_eigen(REAL(X.data()), X.nrow(), X.ncol());
  auto v = as_cpp<std::vector<double>>(tiv);

  std::vector<MatrixXd> effects(beta.size(), MatrixXd::Zero(beta[0].nrow(), v.size()));

  #pragma omp parallel for num_threads(cores)
  for (auto i = 0; i < beta.size(); i++) {
    eigen_predict(effects[i], beta_eigen[i], zeta_eigen[i], X_eigen, v);
  }

  writable::list out(beta.size());
  for (auto i = 0; i < effects.size(); i++)
    out[i] = as_matrix(effects[i]);

  return out;
}
