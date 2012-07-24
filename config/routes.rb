Quizmemanager::Application.routes.draw do
  
  post "mentions/update"

  match 'auth/:provider/callback' => 'accounts#update_omniauth'
  match "accounts/:id/scores" => "mentions#scores"
  match 'accounts/:id/stats' => 'accounts#stats'
  match 'accounts/:id/rts' => 'accounts#rts'
  match 'questions/export_all_question_data' => 'questions#export_all_question_data'

  resources :accounts
  resources :users
  resources :questions
  resources :posts
  resources :mentions

  root :to => 'accounts#index'
end
