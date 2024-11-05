# A very simple script for Luby Transform Code

import numpy as np
from random import random
from abc import *
from dataclasses import dataclass
from typing import *

@dataclass
class CodewordBatch:
    shift   : int
    index   : np.ndarray
    data    : np.ndarray

@dataclass
class Codeword:
    shift   : int
    index   : np.ndarray
    data    : np.ndarray

class Decoder(ABC):
    @abstractmethod
    def put_one(self, code: Codeword):
        """
        put codeword into decoder
        """
        pass

    @abstractmethod
    def put_bat(self, code: CodewordBatch):
        pass

    @abstractmethod
    def get(self) -> Optional[bytes]:
        """
        get input from decoder
        """
        pass

class Encoder(ABC):
    @abstractmethod
    def put_one(self, data: np.ndarray):
        """
        put input into encoder
        """
        pass

    @abstractmethod
    def put_bat(self, data: np.ndarray):
        """
        put input into encoder
        """
        pass

    @abstractmethod
    def get_one(self) -> Codeword:
        """
        get codeword from encoder
        """
        pass

    @abstractmethod
    def get_bat(self) -> CodewordBatch:
        """
        get codeword from encoder
        """
        pass

class LTEncoder(Encoder):
    """
    Luby Transform Encoder
    """
    def __init__(self, dd: np.ndarray, psize: int):
        """
        @param(dd): degree distribution array of shape [d]
        @param(psize): the input code word size
        @field(data): data, array of shape [l]
        """
        super().__init__()
        self.data = np.zeros((0, psize), dtype=np.uint8)
        self.prob = dd.cumsum(0)
        self.prob[-1] = 1

    def get_one(self) -> Codeword:
        """
        @return sample a degree d, and xor d inputs into a codeword
        """
        degree  = (np.random.random() < self.prob).sum() + 1
        index   = np.random.randint(0, self.data.shape[0], size=(degree,))
        return np.bitwise_xor.reduce(self.data[index])

    def get_bat(self, batch: int) -> CodewordBatch:
        """
        @return sample multiple degrees [..d], for each [..d], xor d inputs into a codeword
        """
        degree  = (np.random.random() < self.prob).sum() + 1
        index   = np.random.randint(0, self.data.shape[0], (degree,))
        return np.bitwise_xor.reduce()

    def put_one(self, data: np.ndarray):
        """
        @param(data) one input packet
        """
        assert data.dtype == np.uint8
        assert len(data.shape) == 1
        assert data.shape[-1] == self.data.shape[-1]
        self.data = np.concatenate([self.data, data.reshape(1, -1)], axis=0)

    def put_bat(self, data: np.ndarray):
        """
        @param(data) a batch of input packets 
        """
        assert data.dtype == np.uint8
        assert len(data.shape) == 2
        assert data.shape[-1] == self.data.shape[-1]
        self.data = np.concatenate([self.data, data], axis=0)

class LTDecoder(Decoder):
    """
    Peeling Decoder
    """
    def __init__(self):
        self.buff = []

if __name__ == '__main__':
    encoder = LTEncoder(np.array([0.5, 0.5]), 1024)
    encoder.put_one(np.zeros(1024, dtype=np.uint8))
    encoder.put_one(np.ones(1024, dtype=np.uint8))
    print(encoder.get_one())
