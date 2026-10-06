# frozen_string_literal: true

RecordingStudioCompany::Engine.routes.draw do
  resources :recordings, only: [] do
    resources :companies, only: %i[index new create]
  end

  resources :companies, only: %i[show edit update destroy] do
    member do
      post :restore
      patch :logo, action: :set_logo
      delete :logo, action: :remove_logo
    end
  end
end
