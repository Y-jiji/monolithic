from transformers import AutoTokenizer, AutoModelForCausalLM

token = "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"
model_name = "meta-llama/Llama-3.1-8B"
tokenizer = AutoTokenizer.from_pretrained(model_name, token=token)
model = AutoModelForCausalLM.from_pretrained(model_name, token=token)
