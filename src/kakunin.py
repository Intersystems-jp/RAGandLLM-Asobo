# clipのモデルの次元数を確認
from transformers import AutoProcessor, CLIPModel
import torch

# モデルの読み込み
model = CLIPModel.from_pretrained("line-corporation/clip-japanese-base", trust_remote_code=True)
processor = AutoProcessor.from_pretrained("line-corporation/clip-japanese-base", trust_remote_code=True)

# テキスト入力
texts = ["アジ"]
inputs = processor(text=texts, padding=True) 

# トークナイズ済みのinput_idsとattention_maskをTensor化
input_ids = torch.tensor(inputs["input_ids"])
attention_mask = torch.tensor(inputs["attention_mask"])

with torch.no_grad():
    text_embeds = model.get_text_features(input_ids=input_ids, attention_mask=attention_mask)

print("ベクトル形状:", text_embeds.shape)
print("ベクトル次元数:", text_embeds.shape[-1])
